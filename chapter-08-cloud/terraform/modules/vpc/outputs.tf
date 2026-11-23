output "vpc_id" {
  value       = aws_vpc.main.id
  description = "ID of the created VPC."
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "IDs of the public subnets, one per AZ."
}

output "internet_gateway_id" {
  value       = aws_internet_gateway.main.id
  description = "ID of the internet gateway."
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "IDs of the private subnets (empty when private_subnet_count = 0)."
}

output "nat_gateway_public_ip" {
  value       = try(aws_eip.nat[0].public_ip, null)
  description = "Public IP that private subnets use to reach the internet (null when there is no NAT)."
}
