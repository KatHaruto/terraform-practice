resource "aws_glue_catalog_database" "main" {
  name = "rds_database"
}

resource "aws_glue_crawler" "rds" {
    database_name = aws_glue_catalog_database.main.name
    name          = "RDS"
    role          = aws_iam_role.glue_rds_cralwer.arn

    s3_target {
        path = "s3://${aws_s3_bucket.snapshot_exporter_bucket.bucket}/"
    }
}

resource "aws_iam_role" "glue_rds_cralwer" {
  name = "glue-rds-crawler"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Effect = "Allow"
            Principal = {
            Service = "glue.amazonaws.com"
            }
            Action = "sts:AssumeRole"
        }
        ]
    })

    managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"]
}

resource "aws_iam_role_policy" "glue_rds_cralwer" {
    role = aws_iam_role.glue_rds_cralwer.id
    name = "glue-rds-crawler-policy"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "s3:GetObject",
                ]
                Resource = [
                    "${aws_s3_bucket.snapshot_exporter_bucket.arn}",
                    "${aws_s3_bucket.snapshot_exporter_bucket.arn}/*"
                ]
            },
            {
                Effect = "Allow"
                Action = [
                    "kms:Decrypt",
                ]
                Resource = "${aws_kms_key.main.arn}"
            }
        ]
    })
}