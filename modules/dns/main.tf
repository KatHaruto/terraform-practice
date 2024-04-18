# ---------------------------------------------
# Route53
# ---------------------------------------------
data "aws_route53_zone" "zone" {
  name = var.domain_name
}

resource "aws_route53_record" "aws_ses_validation_record" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = "60"
  records = [var.aws_ses_domain_identity_verification_token]
}

resource "aws_route53_record" "aws_ses_dkim_record" {
  count   = 3 # length(var.aws_ses_domain_dkim_tokens)としようと思ったがエラーが出たので単純に3としている
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "${var.aws_ses_domain_dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  records = ["${var.aws_ses_domain_dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "aws_ses_dmarc_record" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "_dmarc"
  type    = "TXT"
  ttl     = "60"
  records = ["v=DMARC1; p=none"]
}


resource "aws_route53_record" "ses_mx_record" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = "60"
  records = ["10 inbound-smtp.${var.aws_ses_region}.amazonaws.com"]
}

resource "aws_route53_zone" "engineebase_ml_domain" {
  name = "ml.${var.domain_name}"
}

resource "aws_route53_record" "ns_record_for_engineebase_ml_domain" {
  name    = aws_route53_zone.engineebase_ml_domain.name
  zone_id = data.aws_route53_zone.zone.id
  records = [
    aws_route53_zone.engineebase_ml_domain.name_servers[0],
    aws_route53_zone.engineebase_ml_domain.name_servers[1],
    aws_route53_zone.engineebase_ml_domain.name_servers[2],
    aws_route53_zone.engineebase_ml_domain.name_servers[3]
  ]
  ttl  = 300
  type = "NS"
}

resource "aws_route53_record" "public_dns_verify" {
  for_each = {
    for dvo in var.aws_acm_domain_validation_options : dvo.domain_name => {
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
  zone_id         = data.aws_route53_zone.zone.zone_id
}