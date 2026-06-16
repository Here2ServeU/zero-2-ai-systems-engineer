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

resource "aws_instance" "nawex_server" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  tags = {
    Name        = "nawex-ai-server"
    Environment = "dev"
    Owner       = "T2S-Mentorship"
  }
}

output "server_ip" {
  value = aws_instance.nawex_server.public_ip
}
