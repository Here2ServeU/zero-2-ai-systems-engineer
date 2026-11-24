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

# ---- the platform ALB (platform-alb.tf) ---------------------------------------
variable "alb_group_name" {
  type        = string
  default     = "zero2ai"
  description = "Ingresses with this ALB group share one load balancer. Must match ingress.groupName in the Helm chart."
}

variable "alb_allowed_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "Who may open the landing page and Grafana. In prod, list your office/VPN ranges."
}

variable "alb_admin_cidrs" {
  type        = list(string)
  default     = []
  description = "Who may open Prometheus and Alertmanager (they have no login). platform-up.sh sets this to your public IP. Empty = not exposed."
}

# Listener port each chapter's Phase 3 app gets on the shared ALB. Must match
# ingress.port in that chapter's cloud/phase3-production values. Only used to draw the
# landing page; the apps open their own ports when they are deployed.
variable "app_ports" {
  type = map(number)
  default = {
    "Ch10 fraud-api"     = 8010
    "Ch11 metrics-api"   = 8011
    "Ch14 fraud-router"  = 8014
    "Ch15 monitored-api" = 8015
    "Ch16 llm-api"       = 8016
    "Ch17 rag-api"       = 8017
    "Ch18 prod-llm"      = 8018
  }
}
