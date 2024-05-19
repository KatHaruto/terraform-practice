locals {
  app_dir_path = "${path.root}/app_sample"
}

resource "aws_ecr_repository" "app_repository" {
  name                 = var.image_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "app_repository_policy" {
  repository = aws_ecr_repository.app_repository.name
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

resource "null_resource" "build_and_push" {
  provisioner "local-exec" {
    command = "aws ecr get-login-password --profile ${var.aws_profile} | docker login -u AWS --password-stdin ${aws_ecr_repository.app_repository.repository_url}"
  }
  provisioner "local-exec" {
    command = "docker build  --platform amd64 -t ${var.image_name}:latest ${local.app_dir_path}"
  }

  provisioner "local-exec" {
    command = "docker tag ${var.image_name}:latest ${aws_ecr_repository.app_repository.repository_url}"
  }

  provisioner "local-exec" {
    command = "docker push ${aws_ecr_repository.app_repository.repository_url}"
  }
}