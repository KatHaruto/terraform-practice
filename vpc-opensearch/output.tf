output "bastion_instace_id" {
  value = aws_instance.bastion.id
}

output "opensearch_domain_endpoint" {
  value = aws_opensearch_domain.opensearch_domain.endpoint
}

output "api_gw_endpoint" {
  value = aws_apigatewayv2_api.main.api_endpoint
}