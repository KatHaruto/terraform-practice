data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_s3_bucket" "bastion_ssm_log_bucket" {
  bucket = "bastion-ssm-log-bucket"
}

resource "aws_s3_bucket_lifecycle_configuration" "bastion_ssm_log_bucket" {
  bucket = aws_s3_bucket.bastion_ssm_log_bucket.bucket

  rule {
    id     = "expire-logs"
    status = "Enabled"

    expiration {
      days = 3
    }
  }
}

resource "aws_iam_role" "bastion_role" {
  name               = "bastion_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  inline_policy {
    name = "put-ssm-logs-to-s3-policy" # ssm-agent logs
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow",
          Action = ["s3:PutObject",
          "s3:GetEncryptionConfiguration"]
          Resource = [
            "${aws_s3_bucket.bastion_ssm_log_bucket.arn}",
            "${aws_s3_bucket.bastion_ssm_log_bucket.arn}/*",
          ]
        }
      ]
    })
  }

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}



# インスタンスプロファイルを作成
resource "aws_iam_instance_profile" "bastion_profile" {
  name = "example_profile"
  role = aws_iam_role.bastion_role.name
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  user_data                   = <<-EOF
    #! /bin/bash
    sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
    sudo systemctl enable amazon-ssm-agent --now    
  EOF
  subnet_id                   = module.vpc.private_subnets[0]
  associate_public_ip_address = true
  metadata_options {
    http_tokens = "required"
  }

  iam_instance_profile = aws_iam_instance_profile.bastion_profile.name

  vpc_security_group_ids = [
    aws_security_group.bastion.id
  ]


}

resource "aws_security_group" "bastion" {
  description = "Control bastion inbound and outbound access"
  name        = "opensearch-bastion-sg"
  vpc_id      = module.vpc.vpc_id


  egress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ssm_document" "session_manager_run_shell" {
  name            = "SSM-SessionManagerRunShell"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0",
    description   = "Document to hold regional settings for Session Manager",
    sessionType   = "Standard_Stream",
    inputs = {
      s3BucketName        = "${aws_s3_bucket.bastion_ssm_log_bucket.id}",
      s3EncryptionEnabled = false

    }
  })

}