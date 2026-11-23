variable "name_prefix" {
  type        = string
  description = "Prefix for Name tags on the VPC, IGW, subnets and route table. Usually <project>-<stack>-<env>."
}

variable "cidr_block" {
  type        = string
  description = "Primary IPv4 CIDR for the VPC. /16 recommended; the module carves /24 public subnets out of it."

  validation {
    condition     = can(cidrnetmask(var.cidr_block))
    error_message = "cidr_block must be a valid IPv4 CIDR (e.g. 10.10.0.0/16)."
  }
}

variable "public_subnet_count" {
  type        = number
  default     = 2
  description = "Number of public subnets, each in a different AZ. EKS (Chapter 10) needs at least 2."

  validation {
    condition     = var.public_subnet_count >= 1 && var.public_subnet_count <= 6
    error_message = "public_subnet_count must be between 1 and 6."
  }
}

variable "subnet_tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags added to every public subnet (e.g. Kubernetes discovery tags in Chapter 10)."
}

variable "private_subnet_count" {
  type        = number
  default     = 0
  description = "Number of private subnets (no public IPs), one per AZ. 0 = none (Chapter 08 default). EKS prod uses 2 or 3."

  validation {
    condition     = var.private_subnet_count >= 0 && var.private_subnet_count <= 6
    error_message = "private_subnet_count must be between 0 and 6."
  }
}

variable "enable_nat_gateway" {
  type        = bool
  default     = false
  description = "Create one NAT gateway so private subnets can reach the internet. Costs ~$32/month plus data. Only used when private_subnet_count > 0."
}

variable "private_subnet_tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags added to every private subnet (e.g. kubernetes.io/role/internal-elb in Chapter 10)."
}
