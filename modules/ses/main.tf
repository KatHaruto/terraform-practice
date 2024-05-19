data "aws_region" "current" {}


data "aws_route53_zone" "zone" {
  name = var.domain_name
}
resource "aws_ses_domain_identity" "main" {
  domain = var.domain_name
}

resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

resource "aws_route53_record" "aws_ses_validation_record" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = "60"
  records = [aws_ses_domain_identity.main.verification_token]
}

resource "aws_route53_record" "aws_ses_dkim_record" {
  count   = 3 # length(var.aws_ses_domain_dkim_tokens)としようと思ったがエラーが出たので単純に3としている
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "${element(aws_ses_domain_dkim.main.dkim_tokens, count.index)}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.main.dkim_tokens, count.index)}.dkim.amazonses.com"]
}

resource "aws_route53_record" "aws_ses_dmarc_record" {
  zone_id = var.domain_hosted_zone_id
  name    = "_dmarc"
  type    = "TXT"
  ttl     = "60"
  records = ["v=DMARC1; p=none"]
}


resource "aws_route53_record" "ses_mx_record" {
  zone_id = var.domain_hosted_zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = "60"
  records = ["10 inbound-smtp.${data.aws_region.current.name}.amazonaws.com"]
}