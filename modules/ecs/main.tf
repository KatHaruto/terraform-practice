locals {
  current-ip       = chomp(data.http.ifconfig.response_body)
  allowed-cidr     = "${local.current-ip}/32"
  app_name         = "example-app"
  sample_secret    = "sample"
  private_key_file = "./ssh/${var.key_name}"
  public_key_file  = "./ssh/${var.key_name}.pub"
}

data "http" "ifconfig" {
  url = "http://ipv4.icanhazip.com"
}


resource "tls_private_key" "keygen" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key_pem" {
  filename = local.private_key_file
  content  = tls_private_key.keygen.private_key_pem
  provisioner "local-exec" {
    command = "chmod 600 ${local.private_key_file}"
  }
}

resource "local_file" "public_key_pem" {
  filename = local.public_key_file
  content  = tls_private_key.keygen.public_key_openssh
  provisioner "local-exec" {
    command = "chmod 600 ${local.public_key_file}"
  }
}

resource "aws_key_pair" "key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.keygen.public_key_openssh
}

resource "aws_ec2_instance_connect_endpoint" "eic_test" {
  subnet_id          = var.vpc_private_subnet_ids[0]
  security_group_ids = [aws_security_group.ssh_eic.id]
  preserve_client_ip = true
}

resource "aws_security_group" "ssh_eic" {
  name   = "${local.app_name}-ssh-eic"
  vpc_id = var.vpc_id

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_caller_identity" "self" {}

resource "aws_ssm_parameter" "sample_secret" {
  name  = "sample_secret"
  type  = "SecureString"
  value = local.sample_secret
}

resource "aws_ecs_cluster" "app_cluster" {
  name = "${local.app_name}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.app_cluster.name
  capacity_providers = [aws_ecs_capacity_provider.example.name]
}

resource "aws_ecs_capacity_provider" "example" {
  name = "${local.app_name}-capacity-provider"
  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.example.arn
    managed_scaling {
      status = "ENABLED"
    }
  }

}

resource "aws_autoscaling_group" "example" {
  name                = "${local.app_name}-asg"
  max_size            = 2
  min_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = var.vpc_private_subnet_ids
  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }
}

resource "aws_security_group" "app_instance_sg" {
  name   = "${local.app_name}-security-group"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app_alb_sg" {
  name   = "${local.app_name}-alb-security-group"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

}

resource "aws_security_group_rule" "app_instace_sg_rule" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app_instance_sg.id
  source_security_group_id = aws_security_group.app_alb_sg.id
}

resource "aws_security_group_rule" "app_instace_sg_rule_eic_ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app_instance_sg.id
  source_security_group_id = aws_security_group.ssh_eic.id
}

data "aws_ssm_parameter" "ecs_amzn2_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

resource "aws_iam_instance_profile" "example" {
  name = "example_profile"
  role = aws_iam_role.instance.name
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "instance" {
  name               = "test_role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"]
}



resource "aws_launch_template" "example" {
  name                   = "${local.app_name}-launch-template"
  image_id               = data.aws_ssm_parameter.ecs_amzn2_ami.value
  instance_type          = "t3.small"
  vpc_security_group_ids = [aws_security_group.app_instance_sg.id]

  key_name = aws_key_pair.key_pair.key_name

  update_default_version = true
  user_data = base64encode(<<-EOF
      #!/bin/bash
      echo ECS_CLUSTER=${aws_ecs_cluster.app_cluster.name} >> /etc/ecs/ecs.config
      sudo dnf install -y ec2-instance-connect
    EOF
  )

  iam_instance_profile {
    arn = aws_iam_instance_profile.example.arn
  }

  metadata_options {
    http_tokens = "required"
  }
}


resource "aws_ecs_service" "default" {
  name            = "${local.app_name}-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = "2"
  launch_type     = "EC2"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  health_check_grace_period_seconds = 30

  load_balancer {
    target_group_arn = aws_lb_target_group.app_alb_tg.arn
    container_name   = var.app-ecr-repo-name
    container_port   = 8000
  }

}

resource "aws_lb" "app_alb" {
  name               = "${local.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_alb_sg.id]
  subnets            = var.vpc_public_subnet_ids
}

resource "aws_lb_listener" "app_alb_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_alb_tg.arn
  }
}

resource "aws_lb_target_group" "app_alb_tg" {
  name     = "${local.app_name}-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    protocol            = "HTTP"
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = 200
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.ecs_task_name
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = 512
  memory                   = 256
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "${var.app-ecr-repo-name}"
      image     = "${data.aws_caller_identity.self.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.app-ecr-repo-name}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 0
        }
      ]
      secrets = [
        {
          name      = "sample_secret"
          valueFrom = "${aws_ssm_parameter.sample_secret.arn}"
        }
      ]
      environment = [
        {
          name  = "PYTHON_ENV"
          value = "production"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group= "true",
          awslogs-group    = "/ecs/${var.app-ecr-repo-name}"
          awslogs-region     = "${var.aws_region}"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# タスク起動用IAMロールの定義
resource "aws_iam_role" "task_execution_role" {
  name = var.iam_ecs_execution_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = ""
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name = "ssm_policy"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Effect : "Allow"
          Action : [
            "ssm:GetParameter",
            "ssm:GetParameters",
            "ssm:GetParametersByPath",
            "logs:CreateLogGroup"
          ]
          Resource = "*"
        }
      ]
    })
  }
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}




# コンテナ用IAMロールの定義
resource "aws_iam_role" "ecs_task" {
  name = var.iam_ecs_task_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = ""
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

}