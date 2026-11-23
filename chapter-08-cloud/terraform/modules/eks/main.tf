###############################################################################
# EKS brick: one Kubernetes control plane + one managed node group.
#
# What it builds (all names start with var.name):
#   - IAM role for the control plane, IAM role for the worker nodes
#   - CloudWatch log group for control-plane logs (with a retention, so logs
#     don't pile up forever)
#   - Optional KMS key that encrypts Kubernetes Secrets at rest
#   - The EKS cluster, using "access entries" (API mode) for who-can-do-what
#   - A managed node group on Amazon Linux 2023
#   - Core add-ons: vpc-cni, kube-proxy, coredns, eks-pod-identity-agent,
#     aws-ebs-csi-driver (disks for Prometheus / RAG later)
#   - Cluster-admin access entries for the people you list
###############################################################################

data "aws_partition" "current" {}

locals {
  partition = data.aws_partition.current.partition
}

# ----------------------------------------------------------------------------
# Control plane IAM role: lets the EKS service manage AWS resources for you.
# ----------------------------------------------------------------------------
data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Create the log group BEFORE the cluster so WE control its retention.
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = var.log_retention_days
}

# Optional envelope encryption for Kubernetes Secrets.
resource "aws_kms_key" "secrets" {
  count = var.enable_secrets_encryption ? 1 : 0

  description             = "Encrypts Kubernetes Secrets in ${var.name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "secrets" {
  count = var.enable_secrets_encryption ? 1 : 0

  name          = "alias/${var.name}-secrets"
  target_key_id = aws_kms_key.secrets[0].key_id
}

# ----------------------------------------------------------------------------
# The cluster (control plane).
# ----------------------------------------------------------------------------
resource "aws_eks_cluster" "this" {
  name     = var.name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.cluster_subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = var.public_access_cidrs
  }

  # "API" mode: access is granted with aws_eks_access_entry (below), not the
  # old aws-auth ConfigMap. The person who runs `terraform apply` is admin.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = var.cluster_log_types

  dynamic "encryption_config" {
    for_each = var.enable_secrets_encryption ? [1] : []
    content {
      resources = ["secrets"]
      provider {
        key_arn = aws_kms_key.secrets[0].arn
      }
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster,
  ]
}

# ----------------------------------------------------------------------------
# Worker nodes.
# ----------------------------------------------------------------------------
data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
    # Lets you open a shell on a node with SSM Session Manager: no SSH keys,
    # no open port 22.
    "AmazonSSMManagedInstanceCore",
  ])

  role       = aws_iam_role.node.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/${each.value}"
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.node_subnet_ids

  ami_type       = var.node_ami_type
  capacity_type  = var.node_capacity_type
  instance_types = var.node_instance_types
  disk_size      = var.node_disk_size_gb

  scaling_config {
    min_size     = var.node_min_size
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
  }

  # Replace nodes one at a time during upgrades, so the app stays up.
  update_config {
    max_unavailable = 1
  }

  labels = {
    "zero2ai/node-group" = "default"
  }

  # Tags the Cluster Autoscaler looks for (it's installed by eks-addons).
  tags = {
    "k8s.io/cluster-autoscaler/enabled"     = "true"
    "k8s.io/cluster-autoscaler/${var.name}" = "owned"
  }

  # The autoscaler changes desired_size at run time; don't fight it.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}

# ----------------------------------------------------------------------------
# Add-ons. Versions are left blank so EKS picks the default version for your
# Kubernetes version; pin them in production once you have tested an upgrade.
# ----------------------------------------------------------------------------
resource "aws_eks_addon" "before_nodes" {
  for_each = toset(["vpc-cni", "kube-proxy", "eks-pod-identity-agent"])

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.value
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # Turn on Kubernetes NetworkPolicy enforcement in the VPC CNI, so the
  # chart's NetworkPolicy (Phase 3) is actually enforced.
  configuration_values = each.value == "vpc-cni" ? jsonencode({ enableNetworkPolicy = "true" }) : null
}

# coredns and the EBS driver run as pods, so they need nodes first.
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.default]
}

# EBS CSI driver: lets pods ask for disks (PersistentVolumeClaims).
# Its permissions come from a Pod Identity role (module below).
module "ebs_csi_role" {
  source = "../pod-identity-role"

  name                = "${var.name}-ebs-csi"
  cluster_name        = aws_eks_cluster.this.name
  namespace           = "kube-system"
  service_account     = "ebs-csi-controller-sa"
  managed_policy_arns = ["arn:${local.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]

  depends_on = [aws_eks_addon.before_nodes]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.default, module.ebs_csi_role]
}

# ----------------------------------------------------------------------------
# Who else may run kubectl as cluster admin (teammates, a CI role, ...).
# ----------------------------------------------------------------------------
resource "aws_eks_access_entry" "admins" {
  for_each = toset(var.admin_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
}

resource "aws_eks_access_policy_association" "admins" {
  for_each = toset(var.admin_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:${local.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admins]
}
