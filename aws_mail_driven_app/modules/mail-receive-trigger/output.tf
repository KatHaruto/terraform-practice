output "aws_s3_bucket_name" {
  value = aws_s3_bucket.mail_bucket.bucket
}

output "lambda_arn" {
  value = aws_lambda_function.hello_world.arn
}