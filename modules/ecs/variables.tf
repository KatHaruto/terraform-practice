variable "ecs_task_name" {
  type = string
}

variable "key_name" {
  type = string
}
variable "aws_region" {
  type = string
}
variable "iam_ecs_execution_role_name" {
  type = string

}
variable "iam_ecs_task_role_name" {
  type = string
}
variable "iam_ecs_task_policy_name" {
  type = string

}
variable "app-ecr-repo-name" {
  type = string

}

variable "vpc_id" {
  type = string
}

variable "vpc_public_subnet_ids" {
  type = list(string)
}

variable "vpc_private_subnet_ids" {
  type = list(string)
}

variable "certificate_arn" {
  type = string
}

