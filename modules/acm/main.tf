resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  depends_on = []

}

resource "aws_acm_certificate_validation" "public" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in var.public_dns_verify : record.fqdn]
}