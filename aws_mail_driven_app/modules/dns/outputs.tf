output "public_dns_verify" {
  value = [for record in aws_route53_record.public_dns_verify : record]
}

output "certificate_arn" {
  value = aws_acm_certificate.cert.arn
}