resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_app_subnet_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 0)
  availability_zone = "ap-northeast-1a"
}

resource "aws_subnet" "public_app_subnet_1c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 1)
  availability_zone = "ap-northeast-1c"
}

resource "aws_subnet" "private_app_subnet_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 2)
  availability_zone = "ap-northeast-1a"
}

resource "aws_subnet" "private_app_subnet_1c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 3)
  availability_zone = "ap-northeast-1c"
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

}


resource "aws_route_table" "main_public_route_table" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "main_private_route_table" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "main_route_igw" {
  route_table_id         = aws_route_table.main_public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
  depends_on             = [aws_route_table.main_public_route_table]
}

resource "aws_route_table_association" "public_app_subnet_1a_association" {
  subnet_id      = aws_subnet.public_app_subnet_1a.id
  route_table_id = aws_route_table.main_public_route_table.id
}

resource "aws_route_table_association" "public_app_subnet_1c_association" {
  subnet_id      = aws_subnet.public_app_subnet_1c.id
  route_table_id = aws_route_table.main_public_route_table.id
}

resource "aws_route_table_association" "private_app_subnet_1a_association" {
  subnet_id      = aws_subnet.private_app_subnet_1a.id
  route_table_id = aws_route_table.main_private_route_table.id
}

resource "aws_route_table_association" "private_app_subnet_1c_association" {
  subnet_id      = aws_subnet.private_app_subnet_1c.id
  route_table_id = aws_route_table.main_private_route_table.id
}


resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
}

resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
  route_table_id  = aws_route_table.main_private_route_table.id
}

resource "aws_vpc_endpoint" "ecs" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ecs"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [aws_subnet.private_app_subnet_1a.id, aws_subnet.private_app_subnet_1c.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

}

resource "aws_vpc_endpoint" "ecs-agent" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ecs-agent"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [aws_subnet.private_app_subnet_1a.id, aws_subnet.private_app_subnet_1c.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

}



resource "aws_vpc_endpoint" "ecs-telemetry" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ecs-telemetry"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [aws_subnet.private_app_subnet_1a.id, aws_subnet.private_app_subnet_1c.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
}



resource "aws_vpc_endpoint" "logs_endpoint" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [aws_subnet.private_app_subnet_1a.id, aws_subnet.private_app_subnet_1c.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr_endpoint" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [aws_subnet.private_app_subnet_1a.id, aws_subnet.private_app_subnet_1c.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_api_endpoint" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [aws_subnet.private_app_subnet_1a.id, aws_subnet.private_app_subnet_1c.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [aws_subnet.private_app_subnet_1a.id, aws_subnet.private_app_subnet_1c.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

}

resource "aws_security_group" "vpc_endpoint" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "ALL"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "ALL"
    cidr_blocks = ["0.0.0.0/0"]
  }
}