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