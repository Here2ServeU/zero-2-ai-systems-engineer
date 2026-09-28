# main.tf — Provider and a minimal EC2 instance
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Look up the newest Amazon Linux 2023 image, so the ID is never out of date
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "zero2ai_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  tags = {
    Name        = "zero2ai-ai-server"
    Environment = "dev"
    Owner       = "T2S-Mentorship"
  }
}

output "server_ip" {
  value = aws_instance.zero2ai_server.public_ip
}
