resource "aws_ecr_repository" "engineebase_ml_repository" {
  name                 = var.image_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "engineebase_ml_repository_policy" {
  repository = aws_ecr_repository.engineebase_ml_repository.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 10 images",
        selection = {
          "tagStatus" : "any",
          "countType" : "imageCountMoreThan",
          "countNumber" : 10
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}