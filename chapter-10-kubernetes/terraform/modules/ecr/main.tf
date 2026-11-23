###############################################################################
# ECR brick: private image registries ("shelves") for the course apps.
# One repository per app, e.g. zero2ai/fraud-api, zero2ai/llm-api.
###############################################################################

resource "aws_ecr_repository" "this" {
  for_each = toset(var.repositories)

  name = "${var.prefix}/${each.value}"

  # IMMUTABLE: a tag like v1.0 can never be overwritten, so "v1.0" always means
  # the same image. Dev uses MUTABLE so you can re-push while learning.
  image_tag_mutability = var.immutable_tags ? "IMMUTABLE" : "MUTABLE"

  # Scan every pushed image for known vulnerabilities.
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  # Lets `terraform destroy` remove repos that still hold images. Fine for a
  # course; turn off for real production registries.
  force_delete = var.force_delete
}

# Keep the registry tidy (and cheap): drop untagged images after 7 days and
# keep only the newest N tagged images.
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the newest ${var.keep_images} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.keep_images
        }
        action = { type = "expire" }
      },
    ]
  })
}
