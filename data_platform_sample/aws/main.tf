module "vpc" {
  source = "terraform-aws-modules/vpc/aws"


  name = "my-vpc"
  cidr = "12.0.0.0/16"

  azs             = ["ap-northeast-1a", "ap-northeast-1c"]
  public_subnets  = ["12.0.1.0/24", "12.0.2.0/24"]
  private_subnets = ["12.0.101.0/24", "12.0.102.0/24"]

}

data "aws_ssm_parameter" "amazonlinux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64" # x86_64
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.amazonlinux_2023.value
  instance_type               = "t2.micro"
  associate_public_ip_address = true

  subnet_id            = module.vpc.public_subnets[0]
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  metadata_options {
    http_tokens = "required"
  }

}

resource "aws_security_group" "bastion_sg" {
  name   = "bastion_instance_sg"
  vpc_id = module.vpc.vpc_id
  egress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "tcp"
    from_port   = 5432
    to_port     = 5432
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }
}


resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_iam_role" "ssm_role" {
  name = "ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]

}