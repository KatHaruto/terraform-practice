data "aws_caller_identity" "current" {}

data "aws_route53_zone" "domain_hosted_zone" {
  name = var.domain
}

provider "aws" {
  region  = var.aws_region
  profile = var.profile_name
}




module "ses" {
  source                = "./modules/ses"
  domain_name           = var.domain
  receiver_address      = "test@${var.domain}"
  domain_hosted_zone_id = local.domain_hosted_zone_id
  s3_bucket_name        = module.mail-receive-trigger.aws_s3_bucket_name
  lambda_arn            = module.mail-receive-trigger.lambda_arn
}

module "dns" {
  source      = "./modules/dns"
  domain_name = var.domain
  sub_domain  = var.sub_domain
  app_alb_dns_name = module.ecs.app_alb_dns_name
  app_alb_zone_id = module.ecs.app_alb_zone_id
}

module "ecr" {
  source      = "./modules/ecr"
  image_name  = "app"
  aws_profile = "personal-account"
}

module "ecs" {
  source                      = "./modules/ecs"
  ecs_task_name               = "app-task"
  aws_region                  = var.aws_region
  key_name                    = "sample-key"
  iam_ecs_execution_role_name = "ecs-app-execution-role"
  iam_ecs_task_role_name      = "app-task-role"
  iam_ecs_task_policy_name    = "app-task-policy"
  app-ecr-repo-name           = "app"
  certificate_arn             = module.dns.certificate_arn
  vpc_id                      = module.network.vpc_id
  vpc_public_subnet_ids       = module.network.public_subnet_ids
  vpc_private_subnet_ids      = module.network.private_subnet_ids
}


module "network" {
  source         = "./modules/network"
  aws_region     = "ap-northeast-1"
  vpc_cidr_block = "10.0.0.0/16"
}


module "mail-receive-trigger" {
  source        = "./modules/mail-receive-trigger"
  domain_name   = var.domain
  bucket_name   = var.ses_s3_bucket_name
  bucket_prefix = ""
  function_name = "mail-receive-trigger-function"
}