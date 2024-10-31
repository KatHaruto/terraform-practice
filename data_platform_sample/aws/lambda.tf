module "snapshot-exporter-lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.11.0"

  function_name = "snapshot-exporter"
  description   = "Snapshot exporter"
  runtime       = "python3.11"
  handler       = "main.lambda_handler"

  source_path = "aws/lambdas/snapshot_exporter"

  environment_variables = {
    S3_BUCKET         = "${aws_s3_bucket.snapshot_exporter_bucket.bucket}"
    RDS_INSTANCE_ID   = "${aws_db_instance.main.identifier}"
    SNAPSHOT_IAM_ROLE = "${aws_iam_role.snapshot_s3_export.arn}"
    KMS_KEY_ID        = "${aws_kms_key.main.arn}"
  }
  timeout = 900


  attach_policies    = true
  number_of_policies = 2
  policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    aws_iam_policy.snapshot_exporter_lambda_policy.arn
  ]
}

resource "aws_iam_policy" "snapshot_exporter_lambda_policy" {
    name = "snapshot-exporter-lambda-policy"
    
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Effect = "Allow"
            Action = [
                "s3:ListBucket",
                "s3:DeleteObject",
            ],
            Resource = [
                "${aws_s3_bucket.snapshot_exporter_bucket.arn}",
                "${aws_s3_bucket.snapshot_exporter_bucket.arn}/*"
            ]
        },
        {
            Effect = "Allow"
            Action = [
                "iam:PassRole",
                "rds:StartExportTask",
                "rds:DescribeDBSnapshots",
                "rds:CreateDBSnapshot",
            ]
            Resource = "*"
        },
        {
            Effect = "Allow"
            Action = [
                "kms:Decrypt",
                "kms:Encrypt",
                "kms:GenerateDataKey*",
                "kms:ReEncryptFrom",
                "kms:ReEncryptTo",
                "kms:CreateGrant",
                "kms:DescribeKey",
                "kms:RetireGrant"
            ]
            Resource = "${aws_kms_key.main.arn}"
        }
        ]
    })
}

resource "aws_scheduler_schedule" "main" {
  name                         = "run-snapshot-exporter"
  schedule_expression_timezone = "Asia/Tokyo"        # 日本のタイムゾーンを指定
  schedule_expression          = "rate(1 hours)" # 日本時間で設定可能！この場合は毎日AM1時0分

  flexible_time_window {
    mode                      = "FLEXIBLE"
    maximum_window_in_minutes = 1
  }

  target {
    arn      = module.snapshot-exporter-lambda.lambda_function_arn
    role_arn = aws_iam_role.scheduler.arn # スケジューラーのIAMロールのARN
  }
}

resource "aws_iam_role" "scheduler" {
    name = "scheduler-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Effect = "Allow"
            Principal = {
                Service = "scheduler.amazonaws.com"
            }
            Action = "sts:AssumeRole"
        }
        ]
    })
}

resource "aws_iam_role_policy" "scheduler" {
    name = "scheduler-policy"
    role = aws_iam_role.scheduler.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Effect = "Allow"
            Action = [
                "lambda:InvokeFunction"
            ]
            Resource ="${module.snapshot-exporter-lambda.lambda_function_arn}"
        }
        ]
    })
  
}