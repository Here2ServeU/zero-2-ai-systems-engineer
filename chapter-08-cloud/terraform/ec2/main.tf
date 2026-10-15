###############################################################################
# EC2 stack: one root, three environments (dev, qa, prod).
#
# This file is intentionally thin. Every real resource lives in a module under
# ../modules/; the root just wires them together and sets the tags.
#
# The backend settings are NOT written here. They come from
# environments/<env>.tfbackend plus the bucket name at `terraform init` time,
# so the same code writes dev, qa and prod to separate state files:
#   s3://<bucket>/ec2/dev/terraform.tfstate
#   s3://<bucket>/ec2/qa/terraform.tfstate
#   s3://<bucket>/ec2/prod/terraform.tfstate
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

# default_tags are added to every resource this stack creates, so the modules
# don't need to know about Environment or Owner at all.
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

locals {
  # The stack name keeps this chapter's resources apart from Chapter 10's
  # eks stack when both run in the same account and environment.
  stack       = "ec2"
  name_prefix = "${var.project_name}-${local.stack}-${var.environment}"

  # Read the SSH public key if you created one; otherwise launch without a key.
  ssh_key_path = pathexpand(var.ssh_public_key_path)
  public_key   = fileexists(local.ssh_key_path) ? trimspace(file(local.ssh_key_path)) : ""
}

module "vpc" {
  source = "../modules/vpc"

  name_prefix         = local.name_prefix
  cidr_block          = var.vpc_cidr
  public_subnet_count = var.public_subnet_count
}

module "ec2" {
  source = "../modules/ec2"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.public_subnet_ids

  ami_name_filter = var.ami_name_filter
  ami_owners      = var.ami_owners

  instance_type       = var.instance_type
  instance_count      = var.instance_count
  root_volume_size_gb = var.root_volume_size_gb

  public_key        = local.public_key
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}
