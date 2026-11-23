variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type        = string
  default     = "zero2ai"
  description = "Prefix for every name. Must match ../backend."
}

variable "environment" {
  type        = string
  description = "dev, qa or prod. Set by environments/<env>.tfvars."

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be dev, qa or prod."
  }
}

variable "owner" {
  type    = string
  default = "T2S-Mentorship"
}

variable "app_namespace" {
  type        = string
  default     = "zero2ai"
  description = "Kubernetes namespace every chapter's app is installed into."
}

# ---- network ----------------------------------------------------------------
variable "vpc_cidr" {
  type        = string
  description = "VPC range. Different from the ec2 stack's ranges so both can exist."
}

variable "az_count" {
  type        = number
  default     = 2
  description = "Availability zones (subnets of each kind). EKS needs at least 2."
}

variable "private_nodes" {
  type        = bool
  default     = false
  description = "true = nodes in private subnets behind one NAT gateway (~$32/month). false = nodes in public subnets (dev)."
}

# ---- cluster ----------------------------------------------------------------
variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "api_public_access_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "Who may reach the Kubernetes API. In prod, list your own IP(s) as /32."
}

variable "cluster_log_types" {
  type    = list(string)
  default = []
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "enable_secrets_encryption" {
  type    = bool
  default = false
}

variable "admin_principal_arns" {
  type        = list(string)
  default     = []
  description = "Extra IAM user/role ARNs that get cluster-admin (teammates, CI)."
}

# ---- nodes ------------------------------------------------------------------
variable "node_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
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

# ---- registries -------------------------------------------------------------
variable "ecr_repositories" {
  type = list(string)
  default = [
    "fraud-api",     # Chapter 10 and 14 (built from chapter-06-docker)
    "metrics-api",   # Chapter 11
    "aiops",         # Chapter 12
    "retrain",       # Chapter 13 (drift check + retraining job)
    "mlflow",        # Chapter 13 (MLflow tracking server)
    "monitored-api", # Chapter 15
    "llm-api",       # Chapter 16
    "rag-api",       # Chapter 17
    "prod-llm",      # Chapter 18
  ]
}

variable "ecr_immutable_tags" {
  type    = bool
  default = false
}
