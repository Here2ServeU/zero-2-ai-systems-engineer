terraform {
  required_version = ">= 1.6.0"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "mlops_artifacts" {
  bucket = var.artifact_bucket_name

  tags = {
    Project = "nawex-mlops-aiops-platform"
    Week    = "05"
  }
}
