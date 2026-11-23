output "repository_urls" {
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
  description = "Map of app name -> full repository URL (<account>.dkr.ecr.<region>.amazonaws.com/<prefix>/<app>)."
}

output "registry" {
  value       = length(aws_ecr_repository.this) > 0 ? split("/", values(aws_ecr_repository.this)[0].repository_url)[0] : null
  description = "Registry host, used by `docker login`."
}
