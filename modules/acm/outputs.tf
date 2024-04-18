output "aws_acm_domain_validation_options" {
  value = aws_acm_certificate.cert.domain_validation_options
}
output "aws_acm_certificate_arn" {
  value = aws_acm_certificate_validation.public.certificate_arn
}