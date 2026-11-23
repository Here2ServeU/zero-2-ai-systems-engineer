variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "zero2ai"
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be dev, qa or prod."
  }
}

variable "app_namespace" {
  type    = string
  default = "zero2ai"
}

variable "enable_monitoring" {
  type        = bool
  default     = true
  description = "Install Prometheus + Grafana (needed from Chapter 11)."
}

variable "enable_external_secrets" {
  type        = bool
  default     = true
  description = "Install External Secrets Operator (Chapters 16-18, Phase 3)."
}

variable "enable_cluster_autoscaler" {
  type        = bool
  default     = true
  description = "Add/remove nodes automatically within the node group's min/max."
}

variable "prometheus_retention" {
  type    = string
  default = "3d"
}

# Chart versions are pinned so every student gets the same thing.
# To see newer ones: helm repo add <name> <url> && helm search repo <chart> --versions
variable "chart_versions" {
  type = object({
    aws_load_balancer_controller = string
    metrics_server               = string
    cluster_autoscaler           = string
    external_secrets             = string
    kube_prometheus_stack        = string
  })
  default = {
    aws_load_balancer_controller = "3.6.3"
    metrics_server               = "3.14.0"
    cluster_autoscaler           = "9.60.0"
    external_secrets             = "2.15.0"
    kube_prometheus_stack        = "93.9.0"
  }
}
