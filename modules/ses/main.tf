resource "aws_ses_domain_identity" "main" {
  domain = var.domain_name
}

resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

resource "aws_ses_receipt_rule_set" "main" {
  rule_set_name = "primary-rules"
}

resource "aws_ses_receipt_rule" "main" {
  recipients    = [var.domain_name]
  name          = "store-and-invoke-lambda"
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name       = var.s3_bucket_name
    object_key_prefix = "raw/"
    position          = 1
  }

  lambda_action {
    function_arn    = var.lambda_arn
    invocation_type = "Event"
    position        = 2
  }
}

resource "aws_ses_active_receipt_rule_set" "main" {
  rule_set_name = "primary-rules"
}