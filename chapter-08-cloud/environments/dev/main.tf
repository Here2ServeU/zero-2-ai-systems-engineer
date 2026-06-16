# environments/dev/main.tf
terraform {
  backend "s3" {
    bucket = "nawex-terraform-state-12345"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" { region = "us-east-1" }

module "ec2" {
  source        = "../../modules/ec2"
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  key_name      = "aws-key"
}

output "server_ip" {
  value = module.ec2.public_ip
}
