output "public_dns_verify" {
  value = [for record in aws_route53_record.public_dns_verify : record]
}