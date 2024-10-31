resource "aws_ecr_repository" "main" {
  name                 = "nginx_server"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "fluentd" {
  name                 = "fluentd"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "null_resource" "ecr_server" {
  triggers = {
    file_content_md5 = md5(file("./aws/server/build_push.sh"))
  }

  provisioner "local-exec" {
    command = "sh ./aws/server/build_push.sh"
    environment = {
      AWS_REGION     = "${var.aws_region}"
      AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
      REPO_URL       = aws_ecr_repository.main.repository_url
      CONTAINER_NAME = "server"
    }
  }

  depends_on = [aws_ecr_repository.main]
}

resource "null_resource" "fluentd" {
  triggers = {
    file_content_md5 = md5(file("./aws/sidecar/build_push.sh"))
  }

  provisioner "local-exec" {
    command = "sh ./aws/sidecar/build_push.sh"
    environment = {
      AWS_REGION     = "${var.aws_region}"
      AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
      REPO_URL       = aws_ecr_repository.fluentd.repository_url
      CONTAINER_NAME = "fluentd"
    }
  }
}

resource "aws_ecs_cluster" "main" {
  name = "server"
}

resource "aws_ecs_service" "main" {
  name            = "server"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn

  desired_count = 1
  launch_type   = "FARGATE"

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "server"
    container_port   = 80
  }

    enable_execute_command = true
}

resource "aws_iam_role" "execution_role" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}

resource "aws_iam_role" "task_role" {
  name = "ecsTaskRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
resource "random_pet" "bucket_name" {
  length = 2
}
resource "aws_s3_bucket" "fluentd_bucket" {
  bucket = "fluentd-log-${random_pet.bucket_name.id}"
}
resource "aws_iam_role_policy" "task_s3_policy" {
  name = "ecsTaskPolicy"
  role = aws_iam_role.task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          "${aws_s3_bucket.fluentd_bucket.arn}",
          "${aws_s3_bucket.fluentd_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/data_platform_sample"
  retention_in_days = 30
}

resource "aws_ecs_task_definition" "main" {
  family             = "server"
  task_role_arn      = aws_iam_role.task_role.arn
  execution_role_arn = aws_iam_role.execution_role.arn
  container_definitions = jsonencode([
    {
      name              = "server"
      image             = "${aws_ecr_repository.main.repository_url}:latest"
      cpu               = 512
      memory            = 1024
      memoryReservation = 512
      logConfiguration = {
        logDriver = "awsfirelens",
      },
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    },
    {
      name              = "fluentd"
      image             = "${aws_ecr_repository.fluentd.repository_url}:latest"
      essential         = true
      memoryReservation = 512
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "/ecs/data_platform_sample",
          awslogs-region        = "${var.aws_region}",
          awslogs-stream-prefix = "fluentd"
        }
      },
      portMappings = [
        {
          containerPort = 24224
          hostPort      = 24224
        }
      ],
      environment = [
        {
          name  = "S3_BUCKET_NAME"
          value = "${aws_s3_bucket.fluentd_bucket.bucket}"
        },
        {
          name  = "AWS_REGION"
          value = "${var.aws_region}"
        }
      ],
      firelensConfiguration = {
        type = "fluentd"
        options = {
          config-file-type = "file"
          config-file-value = "/fluentd/etc/my_fluent.conf"
        }
      }
      user = "0", # https://github.com/hashicorp/terraform-provider-aws/issues/11526#issuecomment-1202921276
    }
  ])
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "2048"
  network_mode             = "awsvpc"

  track_latest = true

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }


  depends_on = [aws_cloudwatch_log_group.main]

}


resource "aws_security_group" "ecs" {
  name_prefix = "ecs-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id          = module.vpc.vpc_id
  service_name    = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = module.vpc.private_route_table_ids
}

resource "aws_vpc_endpoint_route_table_association" "main" {
  count           = length(module.vpc.private_subnets)
  route_table_id  = module.vpc.private_route_table_ids[count.index]
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  private_dns_enabled = true


  vpc_endpoint_type = "Interface"
  subnet_ids        = module.vpc.private_subnets

  security_group_ids = [aws_security_group.vpc_endpoint.id]
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true


  security_group_ids = [aws_security_group.vpc_endpoint.id]
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

}

# resource "aws_vpc_endpoint" "ssm" {
#    vpc_id              = module.vpc.vpc_id
#    service_name        = "com.amazonaws.${var.aws_region}.ssm"
#    vpc_endpoint_type   = "Interface"
#    subnet_ids          = module.vpc.private_subnets
#    security_group_ids  = [aws_security_group.vpc_endpoint.id]
#    private_dns_enabled = true  
# }

resource "aws_vpc_endpoint" "ssmmessages" {
    vpc_id              = module.vpc.vpc_id
    service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
    vpc_endpoint_type   = "Interface"
    subnet_ids          = module.vpc.private_subnets
    security_group_ids  = [aws_security_group.vpc_endpoint.id]
    private_dns_enabled = true  
  
}
resource "aws_security_group" "vpc_endpoint" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

}

resource "aws_lb" "main" {
  name               = "server"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_security_group" "alb_sg" {
  name_prefix = "alb-"
  vpc_id      = module.vpc.vpc_id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "main" {
  name     = "server"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  target_type = "ip"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  certificate_arn = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}