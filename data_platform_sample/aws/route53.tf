data "aws_route53_zone" "parent" {
  name = var.aws_domain
}

resource "aws_route53_zone" "main" {
  name = "appsub.${var.aws_domain}"
}

resource "aws_route53_record" "parent_ns" {
  zone_id = data.aws_route53_zone.parent.id
  name    = aws_route53_zone.main.name
  type    = "NS"
  ttl     = "300"
  records = [
    aws_route53_zone.main.name_servers[0],
    aws_route53_zone.main.name_servers[1],
    aws_route53_zone.main.name_servers[2],
    aws_route53_zone.main.name_servers[3],
  ]
}



resource "aws_route53_record" "main" {
  type = "A"

  name    = aws_route53_zone.main.name
  zone_id = aws_route53_zone.main.id

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}