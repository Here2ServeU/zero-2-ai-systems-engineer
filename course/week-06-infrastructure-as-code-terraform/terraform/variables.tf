variable "aws_region" {
  description = "AWS region for NAWEX infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "artifact_bucket_name" {
  description = "S3 bucket used for model and pipeline artifacts"
  type        = string
  default     = "nawex-mlops-artifacts-dev"
}
