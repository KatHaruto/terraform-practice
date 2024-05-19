output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public_app_subnet_1a.id, aws_subnet.public_app_subnet_1c.id]
}

output "private_subnet_ids" {
  value = [aws_subnet.private_app_subnet_1a.id, aws_subnet.private_app_subnet_1c.id]
}