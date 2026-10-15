output "environment" {
  value       = var.environment
  description = "Environment this state file represents."
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC the servers run in."
}

output "instance_ids" {
  value       = module.ec2.instance_ids
  description = "IDs of the servers."
}

output "server_ips" {
  value       = module.ec2.public_ips
  description = "Public IP address of each server."
}

output "ami_id" {
  value       = module.ec2.ami_id
  description = "AMI ID that the lookup selected."
}

output "ami_name" {
  value       = module.ec2.ami_name
  description = "Name of the AMI that the lookup selected."
}

output "ssh_commands" {
  value = [
    for ip in module.ec2.public_ips :
    "ssh -i ${trimsuffix(var.ssh_public_key_path, ".pub")} ec2-user@${ip}"
  ]
  description = "Ready-to-paste SSH commands (Amazon Linux user is ec2-user; Ubuntu is ubuntu)."
}
