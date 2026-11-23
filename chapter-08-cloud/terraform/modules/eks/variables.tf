variable "name" {
  type        = string
  description = "Cluster name, also the prefix for its IAM roles and log group. Usually <project>-eks-<env>."
}

variable "kubernetes_version" {
  type        = string
  default     = "1.35"
  description = "Kubernetes minor version. Check what EKS offers: aws eks describe-cluster-versions --query 'clusterVersions[].clusterVersion'"
}

variable "cluster_subnet_ids" {
  type        = list(string)
  description = "Subnets for the control plane's network interfaces (at least 2 AZs)."

  validation {
    condition     = length(var.cluster_subnet_ids) >= 2
    error_message = "EKS needs subnets in at least 2 availability zones."
  }
}

variable "node_subnet_ids" {
  type        = list(string)
  description = "Subnets the worker nodes run in. Public (dev, cheap) or private (prod, safer)."
}

variable "public_access_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "Who may reach the Kubernetes API from the internet. Narrow to your IP / office in prod."
}

variable "cluster_log_types" {
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
  description = "Control-plane logs sent to CloudWatch. [] turns them off (cheapest)."
}

variable "log_retention_days" {
  type        = number
  default     = 7
  description = "How long CloudWatch keeps control-plane logs."
}

variable "enable_secrets_encryption" {
  type        = bool
  default     = false
  description = "Encrypt Kubernetes Secrets with a KMS key (~$1/month). On in prod."
}

variable "node_ami_type" {
  type        = string
  default     = "AL2023_x86_64_STANDARD"
  description = "Node OS image. Use AL2023_ARM_64_STANDARD with Graviton (t4g/m7g) instance types."
}

variable "node_capacity_type" {
  type        = string
  default     = "ON_DEMAND"
  description = "ON_DEMAND or SPOT. SPOT is up to ~70% cheaper but nodes can be taken back with 2 minutes' notice."

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "EC2 sizes for worker nodes. With SPOT, list several to improve availability."
}

variable "node_disk_size_gb" {
  type        = number
  default     = 30
  description = "Root disk per node. Images for the RAG chapter are large; 30 GB leaves room."
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "admin_principal_arns" {
  type        = list(string)
  default     = []
  description = "Extra IAM users/roles given cluster-admin. The person running apply is admin automatically."
}
