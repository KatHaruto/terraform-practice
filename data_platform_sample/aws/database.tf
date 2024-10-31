resource "aws_db_subnet_group" "main" {
  name       = "testdb"
  subnet_ids = module.vpc.private_subnets

}
resource "aws_db_instance" "main" {
  identifier              = "testdb"
  db_name                 = "postgres"
  allocated_storage       = 20
  storage_type            = "gp2"
  engine                  = "postgres"
  engine_version          = "16.3"
  instance_class          = "db.t4g.micro"
  db_subnet_group_name    = aws_db_subnet_group.main.name
  password                = var.aws_db_password
  username                = var.aws_db_username
  backup_retention_period = 0
  multi_az                = false
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.rds.id]
}

resource "aws_security_group" "rds" {
  description = "Allow access to RDS"
  name        = "test-rds-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    protocol  = "tcp"
    from_port = 5432
    to_port   = 5432
    security_groups = [
    aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "snapshot_s3_export" {

  name = "snapshot-s3-export"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "export.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "snapshot_s3_export" {
  role = aws_iam_role.snapshot_s3_export.id
  name = "snapshot-s3-export-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action =  [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
        Resource= "arn:aws:s3:::*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject*",
          "s3:GetObject*",
          "s3:DeleteObject*",
          ],
        Resource = [
          "${aws_s3_bucket.snapshot_exporter_bucket.arn}",
          "${aws_s3_bucket.snapshot_exporter_bucket.arn}/*"
        ]
      }
    ]
  })
}