output "artifact_bucket_name" {
  description = "Artifact bucket for MLOps assets"
  value       = aws_s3_bucket.mlops_artifacts.bucket
}
