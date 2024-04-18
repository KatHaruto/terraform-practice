output "aws_ses_domain_identity_verification_token" {
  value = aws_ses_domain_identity.main.verification_token
}

output "aws_ses_domain_dkim_tokens" {
  value = aws_ses_domain_dkim.main.dkim_tokens
}

output "aws_ses_invoke_lambda_receipt_rule_arn" {
  value = aws_ses_receipt_rule.main.arn
}