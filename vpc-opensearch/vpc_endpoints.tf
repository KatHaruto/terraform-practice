resource "aws_vpc_endpoint" "bedrock" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.ap-northeast-1.bedrock-runtime"
  security_group_ids = [aws_security_group.vpc-endpoint-bedrock-sg.id]

  private_dns_enabled = true

  vpc_endpoint_type = "Interface"

}

resource "aws_security_group" "vpc-endpoint-bedrock-sg" {
  name        = "vpc-endpoint-bedrock-sg"
  description = "Managed by Terraform"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "vpc-endpoint-bedrock-sg-igress" {
  security_group_id        = aws_security_group.vpc-endpoint-bedrock-sg.id
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ingest-to-opensearch-lambda-sg.id
}


resource "aws_vpc_endpoint_subnet_association" "main" {
  vpc_endpoint_id = aws_vpc_endpoint.bedrock.id
  subnet_id       = module.vpc.private_subnets[0]
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.ap-northeast-1.ssmmessages"
  security_group_ids = [aws_security_group.vpc-endpoint-ssm-sg.id]

  private_dns_enabled = true
  vpc_endpoint_type   = "Interface"
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.ap-northeast-1.ec2messages"
  security_group_ids = [aws_security_group.vpc-endpoint-ssm-sg.id]

  private_dns_enabled = true
  vpc_endpoint_type   = "Interface"
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.ap-northeast-1.ssm"
  security_group_ids = [aws_security_group.vpc-endpoint-ssm-sg.id]

  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
}

resource "aws_security_group" "vpc-endpoint-ssm-sg" {
  name        = "vpc-endpoint-ssm-sg"
  description = "Managed by Terraform"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = ["0.0.0.0/0"]

  }
}

resource "aws_vpc_endpoint_subnet_association" "ssm" {
  vpc_endpoint_id = aws_vpc_endpoint.ssm.id
  subnet_id       = module.vpc.private_subnets[0]
}

resource "aws_vpc_endpoint_subnet_association" "ssmmessages" {
  vpc_endpoint_id = aws_vpc_endpoint.ssmmessages.id
  subnet_id       = module.vpc.private_subnets[0]
}

resource "aws_vpc_endpoint_subnet_association" "ec2messages" {
  vpc_endpoint_id = aws_vpc_endpoint.ec2messages.id
  subnet_id       = module.vpc.private_subnets[0]
}

resource "aws_vpc_endpoint" "ssm-s3" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.ap-northeast-1.s3"

  route_table_ids   = [module.vpc.private_route_table_ids[0]]
  vpc_endpoint_type = "Gateway"
}