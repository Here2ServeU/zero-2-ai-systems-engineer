# backend/s3.tf
provider "aws" { region = "us-east-1" }

resource "aws_s3_bucket" "tf_state" {
  bucket = "nawex-terraform-state-12345"
  tags   = { Name = "T2S-Terraform-State" }
}
