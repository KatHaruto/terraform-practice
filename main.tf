provider "aws" {
  region  = var.region
  profile = var.profile_name
}

terraform {
  required_version = "~>1.8.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.45.0"
    }
  }
}

module "lambda" {
  source                         = "./modules/lambda"
  function_name                  = "hello_world"
  ses_invoke_lambda_rule_set_arn = module.ses.aws_ses_invoke_lambda_receipt_rule_arn
}

module "s3" {
  source      = "./modules/s3"
  bucket_name = var.ses_s3_bucket_name
}

module "ses" {
  source           = "./modules/ses"
  domain_name      = var.domain
  receiver_address = "test@${var.domain}"
  ses_region       = var.region

  s3_bucket_name = module.s3.aws_s3_bucket_name
  lambda_arn     = module.lambda.lambda_arn
}

module "dns" {
  source      = "./modules/dns"
  domain_name = var.domain

  aws_ses_region                             = var.region
  aws_ses_domain_identity_verification_token = module.ses.aws_ses_domain_identity_verification_token
  aws_ses_domain_dkim_tokens                 = module.ses.aws_ses_domain_dkim_tokens
}