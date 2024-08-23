variable "aws_profile" {}
variable "aws_region" {}
variable "resource_prefix" {}
variable "aws_cross_account_id" {}
variable "aws_cross_account_logs_assume_role_name" {}

locals {
  cross_account_logs_assume_role_arn = "arn:aws:iam::${var.aws_cross_account_id}:role/${var.aws_cross_account_logs_assume_role_name}"
}


provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

################################
# LambdaにアタッチするIAM Role
################################

resource "aws_iam_role" "ingest_opensearch_lambda_role" {
  name = "${var.resource_prefix}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name = "elastic-search-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["es:*"]
          Resource = ["${aws_opensearch_domain.opensearch_domain.arn}/*"]
        },
        {
          Effect   = "Allow"
          Action   = ["bedrock:*"]
          Resource = ["*"]
        }
      ]
    })
  }
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"]
}

resource "aws_iam_role" "search_opensearch_lambda_role" {
  name = "search_opensearch_lambda_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name = "elastic-search-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["es:*"]
          Resource = ["${aws_opensearch_domain.opensearch_domain.arn}/*"]
        }
      ]
    })
  }
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"]

}

resource "aws_iam_role" "hourly_data_collect_lambda_role" {
  name = "hourly_data_collect_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name = "logs-query-assume-role-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["sts:AssumeRole"]
          Resource = "${local.cross_account_logs_assume_role_arn}"
        }
      ]
      }
    )
  }

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

}



resource "aws_lambda_permission" "api-gw-invoke-ingest-opensearch-lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest_to_opensearch.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
resource "aws_lambda_permission" "api-gw-invoke-search-opensearch-lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.search_to_opensearch.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "eventbridge-scheduler-invoke-hourly-collect-lambda" {
  statement_id  = "AllowExecutionFromEventBridgeScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hourly_data_collect.function_name
  principal     = "scheduler.amazonaws.com"
}
################################
# Lambda
################################

# apiディレクトリにLambdaのソースコードがある前提
# apiディレクトリを api.zip という名前に固めて resource "aws_lambda_function" "api" から参照できるようにする
data "archive_file" "ingest_to_opensearch_source_zip" {
  type        = "zip"
  source_dir  = "functions/transform-and-inject-opensearch/build/function"
  output_path = "functions/transform-and-inject-opensearch/output/function.zip"
}

data "archive_file" "ingest_to_opensearch_layer_zip" {
  type        = "zip"
  source_dir  = "functions/transform-and-inject-opensearch/build/layer"
  output_path = "functions/transform-and-inject-opensearch/output/layer.zip"
}

resource "aws_lambda_layer_version" "ingest_to_opensearch_lambda_layer" {
  layer_name       = "${var.resource_prefix}_lambda_layer"
  filename         = data.archive_file.ingest_to_opensearch_layer_zip.output_path
  source_code_hash = data.archive_file.ingest_to_opensearch_layer_zip.output_base64sha256
}

resource "aws_lambda_function" "ingest_to_opensearch" {
  depends_on       = [aws_iam_role.ingest_opensearch_lambda_role]
  filename         = data.archive_file.ingest_to_opensearch_source_zip.output_path
  function_name    = "${var.resource_prefix}-function"
  role             = aws_iam_role.ingest_opensearch_lambda_role.arn
  handler          = "src/main.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.ingest_to_opensearch_source_zip.output_base64sha256

  timeout = 30

  vpc_config {
    # Every subnet should be able to reach an EFS mount target in the same Availability Zone. Cross-AZ mounts are not permitted.
    subnet_ids         = [module.vpc.private_subnets[0]]
    security_group_ids = [aws_security_group.ingest-to-opensearch-lambda-sg.id]
  }

  environment {
    variables = {
      "ES_ENDPOINT" = aws_opensearch_domain.opensearch_domain.endpoint
      "LAMBDA_ENV"  = "production"
      //"PERSONNEL_INDEX" = opensearch_index.personnel.name
    }
  }

  layers = ["${aws_lambda_layer_version.ingest_to_opensearch_lambda_layer.arn}"]
}


resource "aws_security_group" "ingest-to-opensearch-lambda-sg" {
  name   = "lambda-security-group"
  vpc_id = module.vpc.vpc_id

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

data "archive_file" "search_opensearch_source_zip" {
  type        = "zip"
  source_dir  = "functions/search-opensearch/build/function"
  output_path = "functions/search-opensearch/output/function.zip"
}

data "archive_file" "search_opensearch_layer_zip" {
  type        = "zip"
  source_dir  = "functions/search-opensearch/build/layer"
  output_path = "functions/search-opensearch/output/layer.zip"
}

resource "aws_lambda_layer_version" "search_opensearch_lambda_layer" {
  layer_name       = "search_openseach_lambda_layer"
  filename         = data.archive_file.search_opensearch_layer_zip.output_path
  source_code_hash = data.archive_file.search_opensearch_layer_zip.output_base64sha256
}

resource "aws_lambda_function" "search_to_opensearch" {
  depends_on       = [aws_iam_role.search_opensearch_lambda_role]
  filename         = data.archive_file.search_opensearch_source_zip.output_path
  function_name    = "search_opensearch"
  role             = aws_iam_role.search_opensearch_lambda_role.arn
  handler          = "src/main.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.search_opensearch_source_zip.output_base64sha256

  timeout = 30

  vpc_config {
    # Every subnet should be able to reach an EFS mount target in the same Availability Zone. Cross-AZ mounts are not permitted.
    subnet_ids         = [module.vpc.private_subnets[0]]
    security_group_ids = [aws_security_group.ingest-to-opensearch-lambda-sg.id]
  }

  environment {
    variables = {
      "ES_ENDPOINT" = aws_opensearch_domain.opensearch_domain.endpoint
      "LAMBDA_ENV"  = "production"
      //"PERSONNEL_INDEX" = opensearch_index.personnel.name
    }
  }

  layers = ["${aws_lambda_layer_version.search_opensearch_lambda_layer.arn}"]
}

data "archive_file" "hourly_data_collect_source_zip" {
  type        = "zip"
  source_dir  = "functions/hourly-data-collect/build/function"
  output_path = "functions/hourly-data-collect/output/function.zip"
}

data "archive_file" "hourly_data_collect_layer_zip" {
  type        = "zip"
  source_dir  = "functions/hourly-data-collect/build/layer"
  output_path = "functions/hourly-data-collect/output/layer.zip"
}

resource "aws_lambda_layer_version" "hourly_data_collect_lambda_layer" {
  layer_name       = "hourly_data_collect_lambda_layer"
  filename         = data.archive_file.hourly_data_collect_layer_zip.output_path
  source_code_hash = data.archive_file.hourly_data_collect_layer_zip.output_base64sha256
}

resource "aws_lambda_function" "hourly_data_collect" {
  depends_on       = [aws_iam_role.hourly_data_collect_lambda_role]
  filename         = data.archive_file.hourly_data_collect_source_zip.output_path
  function_name    = "hourly_data_collect_function"
  role             = aws_iam_role.hourly_data_collect_lambda_role.arn
  handler          = "src/main.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.hourly_data_collect_source_zip.output_base64sha256

  timeout = 900

  environment {
    variables = {
      "API_GW_ENDPOINT"     = aws_apigatewayv2_api.main.api_endpoint
      "LOGS_QUERY_ROLE_ARN" = local.cross_account_logs_assume_role_arn
    }
  }

  layers = ["${aws_lambda_layer_version.hourly_data_collect_lambda_layer.arn}"]
}


################################
# API Gateway
################################

resource "aws_cloudwatch_log_group" "main" {
  name              = "/aws/api-gw/${aws_apigatewayv2_api.main.name}"
  retention_in_days = 30
}

resource "aws_iam_role" "api_gw_cloudwatch_role" {
  name = "${var.resource_prefix}-api-gw-cloudwatch-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"]

}

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gw_cloudwatch_role.arn
}

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.resource_prefix}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["*"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }
}

resource "aws_apigatewayv2_route" "ingest_opensearch_lambda_post_route" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /"
  target    = "integrations/${aws_apigatewayv2_integration.ingest_opensearch_lambda_post_integration.id}"

}

resource "aws_apigatewayv2_integration" "ingest_opensearch_lambda_post_integration" {
  api_id             = aws_apigatewayv2_api.main.id
  connection_type    = "INTERNET"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.ingest_to_opensearch.invoke_arn
  integration_type   = "AWS_PROXY"
}

resource "aws_apigatewayv2_route" "search_opensearch_lambda_get_route" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /search"
  target    = "integrations/${aws_apigatewayv2_integration.search_opensearch_lambda_post_integration.id}"

}

resource "aws_apigatewayv2_integration" "search_opensearch_lambda_post_integration" {
  api_id             = aws_apigatewayv2_api.main.id
  connection_type    = "INTERNET"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.search_to_opensearch.invoke_arn
  integration_type   = "AWS_PROXY"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  auto_deploy = true
  name        = "$default"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.main.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
  default_route_settings {
    throttling_burst_limit = 1000
    throttling_rate_limit  = 100
  }

}

# eventbridge scheduler
resource "aws_iam_role" "eventbridge_scheduler" {
  name = "eventbridge_scheduler_invoke_lambda_role"
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

  inline_policy {
    name = "eventbridge-scheduler-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["lambda:InvokeFunction"]
          Resource = ["${aws_lambda_function.hourly_data_collect.arn}"]
        }
      ]
    })
  }
}

resource "aws_scheduler_schedule_group" "example" {
  name = "example"
}

resource "aws_scheduler_schedule" "lambda" {
  name       = "example"
  group_name = aws_scheduler_schedule_group.example.name

  state = "ENABLED"

  schedule_expression          = "cron(0 6-21/1 * * ? *)"
  schedule_expression_timezone = "Asia/Tokyo"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.hourly_data_collect.arn
    role_arn = aws_iam_role.eventbridge_scheduler.arn
  }
}
