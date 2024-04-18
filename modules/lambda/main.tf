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

# Policy
# 中身はAWSLambdaBasicExecutionRoleと同じのためマネージドポリシーを利用して以下はコメントアウト
# resource "aws_iam_role_policy" "lambda_access_policy" {
#  name = "${var.function_name}_lambda_access_policy"
#  role = aws_iam_role.lambda_iam_role.id
#  policy = jsonencode({
#    Version = "2012-10-17",
#    Statement = [
#      {
#        Effect = "Allow",
#        Action = [
#          "logs:CreateLogStream",
#          "logs:CreateLogGroup",
#          "logs:PutLogEvents"
#        ],
#        Resource = "arn:aws:logs:*:*:*"
#      }
#    ]
#  })
#}