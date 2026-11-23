###############################################################################
# EKS stack (Chapter 10 onward): the cloud platform for chapters 10-18.
#
# Everything Chapter 10 needs lives in chapter-10-kubernetes/terraform: its own
# S3 backend (../backend), its own copy of the vpc module, and the same
# dev / qa / prod environment files you know from Chapter 08. It adds:
#   - modules/eks              the cluster + node group + core add-ons
#   - modules/ecr              private image registries for every chapter's app
#   - modules/pod-identity-role AWS permissions for specific pods, no keys
#   - an S3 bucket for MLflow model artifacts (Chapter 13)
#   - a Secrets Manager secret for LLM API keys (Chapters 16-18)
#
# Kubernetes software that runs ON the cluster (load balancer controller,
# metrics-server, Prometheus/Grafana, External Secrets, autoscaler) is in the
# separate ../eks-addons stack, installed with Helm. Two stacks = two smaller
# states: you can reinstall add-ons without touching the cluster.
###############################################################################

terraform {
  required_version = ">= 1.5"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Stack       = local.stack
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  stack        = "eks"
  name_prefix  = "${var.project_name}-${local.stack}-${var.environment}"
  cluster_name = local.name_prefix
  partition    = data.aws_partition.current.partition
  account_id   = data.aws_caller_identity.current.account_id

  # Every chapter's app lives in this namespace; the add-ons live in kube-system
  # and monitoring.
  app_namespace = var.app_namespace

  # Prefix for secrets the apps may read (Chapters 16-18).
  secrets_prefix = "${var.project_name}/${var.environment}"
}

# ----------------------------------------------------------------------------
# Network: the same vpc brick as Chapter 08 (copied to ../modules/vpc), plus Kubernetes discovery tags.
# dev: public subnets only (cheap). qa/prod: private subnets + NAT for nodes.
# ----------------------------------------------------------------------------
module "vpc" {
  source = "../modules/vpc"

  name_prefix         = local.name_prefix
  cidr_block          = var.vpc_cidr
  public_subnet_count = var.az_count

  private_subnet_count = var.private_nodes ? var.az_count : 0
  enable_nat_gateway   = var.private_nodes

  # The AWS Load Balancer Controller looks for these tags to know where to put
  # internet-facing (elb) and internal (internal-elb) load balancers.
  subnet_tags = {
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

locals {
  node_subnet_ids = var.private_nodes ? module.vpc.private_subnet_ids : module.vpc.public_subnet_ids
}

# ----------------------------------------------------------------------------
# The cluster.
# ----------------------------------------------------------------------------
module "eks" {
  source = "../modules/eks"

  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version

  cluster_subnet_ids  = local.node_subnet_ids
  node_subnet_ids     = local.node_subnet_ids
  public_access_cidrs = var.api_public_access_cidrs

  cluster_log_types         = var.cluster_log_types
  log_retention_days        = var.log_retention_days
  enable_secrets_encryption = var.enable_secrets_encryption

  node_capacity_type  = var.node_capacity_type
  node_instance_types = var.node_instance_types
  node_min_size       = var.node_min_size
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size

  admin_principal_arns = var.admin_principal_arns
}

# ----------------------------------------------------------------------------
# Image registries: one per chapter app.
# ----------------------------------------------------------------------------
module "ecr" {
  source = "../modules/ecr"

  # Repos are per environment (zero2ai-dev/fraud-api, zero2ai-prod/fraud-api):
  # ECR names are account-wide, so dev and prod must not share a name.
  prefix         = "${var.project_name}-${var.environment}"
  repositories   = var.ecr_repositories
  immutable_tags = var.ecr_immutable_tags
}

# ----------------------------------------------------------------------------
# Pod Identity roles for the add-ons (installed by ../eks-addons with Helm).
# The namespace/service-account pairs here MUST match the Helm values there.
# ----------------------------------------------------------------------------
module "alb_controller_role" {
  source = "../modules/pod-identity-role"

  name               = "${local.cluster_name}-alb-controller"
  cluster_name       = module.eks.cluster_name
  namespace          = "kube-system"
  service_account    = "aws-load-balancer-controller"
  inline_policy_json = file("${path.module}/iam/aws-load-balancer-controller.json")
}

module "cluster_autoscaler_role" {
  source = "../modules/pod-identity-role"

  name            = "${local.cluster_name}-cluster-autoscaler"
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "cluster-autoscaler"
  inline_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Read"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup",
        ]
        Resource = "*"
      },
      {
        # Only node groups tagged as belonging to THIS cluster can be resized.
        Sid    = "ResizeOwnNodeGroups"
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
          }
        }
      },
    ]
  })
}

module "external_secrets_role" {
  source = "../modules/pod-identity-role"

  name            = "${local.cluster_name}-external-secrets"
  cluster_name    = module.eks.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  inline_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ReadCourseSecretsOnly"
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds",
      ]
      Resource = "arn:${local.partition}:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secrets_prefix}/*"
    }]
  })
}

# ----------------------------------------------------------------------------
# Chapter 13: S3 bucket for MLflow artifacts, readable/writable only by the
# MLflow server and the retraining job (their service accounts).
# ----------------------------------------------------------------------------
resource "aws_s3_bucket" "ml_artifacts" {
  bucket        = "${local.name_prefix}-mlflow-${local.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "ml_artifacts" {
  bucket                  = aws_s3_bucket.ml_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ml_artifacts" {
  bucket = aws_s3_bucket.ml_artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

locals {
  ml_artifacts_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.ml_artifacts.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.ml_artifacts.arn}/*"
      },
    ]
  })
}

module "mlflow_role" {
  for_each = toset(["mlflow", "retrain"])
  source   = "../modules/pod-identity-role"

  name               = "${local.cluster_name}-${each.value}"
  cluster_name       = module.eks.cluster_name
  namespace          = local.app_namespace
  service_account    = each.value
  inline_policy_json = local.ml_artifacts_policy
}

# ----------------------------------------------------------------------------
# Chapters 16-18: one Secrets Manager secret that holds the LLM API keys.
# Terraform creates the empty "envelope"; YOU put the value in with
#   chapter-10-kubernetes/scripts/put-llm-secret.sh
# so the key never touches Terraform state or git.
# ----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "llm_api_keys" {
  name        = "${local.secrets_prefix}/llm-api-keys"
  description = "LLM provider API keys for the course apps (JSON: ANTHROPIC_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY)."

  # 0 = delete immediately on destroy, so you can recreate the same name in a
  # new session. Prod keeps a 7-day safety window.
  recovery_window_in_days = var.environment == "prod" ? 7 : 0
}
