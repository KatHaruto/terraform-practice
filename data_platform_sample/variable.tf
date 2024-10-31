variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

variable "aws_domain" {
  type = string
}

variable "aws_db_username" {
  type = string
}

variable "aws_db_password" {
  type      = string
  sensitive = true
}
variable "google_project_id" {
  type = string
}

variable "google_region" {
  type = string
}