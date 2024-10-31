variable "aws_db_username" {
  type = string
}

variable "aws_db_password" {
  type      = string
  sensitive = true
}
variable "aws_domain" {
  type = string
}
variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

variable "athena_workgroup_name" {
  type = string
  default = "sample-workgroup"
}
