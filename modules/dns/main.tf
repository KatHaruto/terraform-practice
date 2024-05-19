# ---------------------------------------------
# Route53 DNS records and zones for ACM
# this does not contain records for the SES service
# ---------------------------------------------
data "aws_route53_zone" "zone" {
  name = var.domain_name
}


resource "aws_route53_zone" "sub_domain" {
  name = "${var.sub_domain}.${var.domain_name}"
}

resource "aws_route53_record" "ns_record_for_sub_domainn" {
  name    = aws_route53_zone.sub_domain.name
  zone_id = data.aws_route53_zone.zone.id
  records = [
    aws_route53_zone.sub_domain.name_servers[0],
    aws_route53_zone.sub_domain.name_servers[1],
    aws_route53_zone.sub_domain.name_servers[2],
    aws_route53_zone.sub_domain.name_servers[3]
  ]
  ttl  = 300
  type = "NS"
}

resource "aws_route53_record" "a_record_for_sub_domain" {
  name    = aws_route53_zone.sub_domain.name
  zone_id = aws_route53_zone.sub_domain.zone_id
  type    = "A"
  
  alias {
    name = var.app_alb_dns_name
    zone_id = var.app_alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "public_dns_verify" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.sub_domain.zone_id
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "${var.sub_domain}.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  depends_on = []

}

resource "aws_acm_certificate_validation" "public" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.public_dns_verify : record.fqdn]
}