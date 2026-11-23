variable "name" {
  type        = string
  description = "IAM role name."
}

variable "cluster_name" {
  type = string
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace of the service account."
}

variable "service_account" {
  type        = string
  description = "Kubernetes service account name that may use this role."
}

variable "managed_policy_arns" {
  type    = list(string)
  default = []
}

variable "inline_policy_json" {
  type    = string
  default = null
}
