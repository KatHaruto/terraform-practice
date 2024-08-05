
resource "aws_s3_bucket" "mail_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_policy" "mail_bucket_policy" {
  bucket = aws_s3_bucket.mail_bucket.id
  policy = data.aws_iam_policy_document.mail_bucket.json
}

data "aws_iam_policy_document" "mail_bucket" {
  statement {
    actions = [
      "s3:PutObject",
    ]

    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }
    resources = [
      "${aws_s3_bucket.mail_bucket.arn}/*",
    ]
  }
}


resource "aws_ses_receipt_rule_set" "main" {
  rule_set_name = "primary-rules"
}

resource "aws_ses_receipt_rule" "main" {
  recipients    = [var.domain_name]
  name          = "store-and-invoke-lambda"
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name       = aws_s3_bucket.mail_bucket.bucket
    object_key_prefix = var.bucket_prefix
    position          = 1
  }

  lambda_action {
    function_arn    = aws_lambda_function.hello_world.arn
    invocation_type = "Event"
    position        = 2
  }

  depends_on = [aws_s3_bucket_policy.mail_bucket_policy]
}

resource "aws_ses_active_receipt_rule_set" "main" {
  rule_set_name = "primary-rules"
}

data "archive_file" "layer_zip" {
  type        = "zip"
  source_dir  = "lambda/build/layer"
  output_path = "lambda/layer.zip"
}
data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "lambda/build/function"
  output_path = "lambda/function.zip"
}

# Layer
resource "aws_lambda_layer_version" "lambda_layer" {
  layer_name       = "${var.function_name}_lambda_layer"
  filename         = data.archive_file.layer_zip.output_path
  source_code_hash = data.archive_file.layer_zip.output_base64sha256
}

# Function
resource "aws_lambda_function" "hello_world" {
  function_name = var.function_name

  handler          = "src/main.lambda_handler"
  filename         = data.archive_file.function_zip.output_path
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_iam_role.arn
  source_code_hash = data.archive_file.function_zip.output_base64sha256
  layers           = ["${aws_lambda_layer_version.lambda_layer.arn}"]
}

resource "aws_lambda_permission" "allow_ses" {
  statement_id  = "allow_ses"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world.function_name
  principal     = "ses.amazonaws.com"
  # source_arn    = var.ses_invoke_lambda_rule_set_arn # source_arnを指定するとエラーになる (循環参照？) セキュリティ的に問題
}

# Role
resource "aws_iam_role" "lambda_iam_role" {
  name = "${var.function_name}_iam_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

}
