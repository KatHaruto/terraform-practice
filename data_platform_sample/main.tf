module "aws" {
  source          = "./aws"
  aws_region      = var.aws_region
  aws_profile     = var.aws_profile
  aws_domain      = var.aws_domain
  aws_db_username = var.aws_db_username
  aws_db_password = var.aws_db_password
}

module "gcp" {
  source            = "./gcp"
  google_project_id = var.google_project_id
  google_region     = var.google_region
}