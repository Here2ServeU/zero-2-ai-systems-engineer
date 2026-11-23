output "region" {
  value = var.aws_region
}

output "environment" {
  value = var.environment
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_version" {
  value = module.eks.cluster_version
}

output "app_namespace" {
  value = var.app_namespace
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "configure_kubectl" {
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name} --alias ${module.eks.cluster_name}"
  description = "Run this to point kubectl at the new cluster."
}

output "ecr_registry" {
  value = module.ecr.registry
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "mlflow_bucket" {
  value = aws_s3_bucket.ml_artifacts.bucket
}

output "llm_secret_name" {
  value = aws_secretsmanager_secret.llm_api_keys.name
}

output "nat_gateway_public_ip" {
  value = module.vpc.nat_gateway_public_ip
}
