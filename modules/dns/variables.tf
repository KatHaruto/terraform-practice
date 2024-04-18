variable "domain_name" {
  type = string
}

variable "aws_ses_region" {
  type = string
}
variable "aws_ses_domain_identity_verification_token" {
  type = string
}

variable "aws_ses_domain_dkim_tokens" {
  type = list(string)
}

variable "aws_acm_domain_validation_options" {
  type = set(object({
    domain_name           = string
    resource_record_name  = string
    resource_record_type  = string
    resource_record_value = string
  }))
}

variable "aws_acm_certificate_arn" {
  type = string
}