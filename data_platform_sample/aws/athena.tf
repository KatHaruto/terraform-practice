resource "random_pet" "athena_workgroup_namebucket_name" {
  length = 2
  
}
resource "aws_s3_bucket" "athena_output_bucket" {
  bucket = "athena-output-bucket-${random_pet.athena_workgroup_namebucket_name.id}"
}

resource "aws_athena_workgroup" "this" {
  name = var.athena_workgroup_name

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_output_bucket.id}/athena-result/"
    }
  }
}

resource "aws_athena_database" "nginx" {
    name = "nginx_logs_db"
    bucket = aws_s3_bucket.fluentd_bucket.bucket  
}


resource "aws_athena_named_query" "create_table" {
  name = "create_nginx_logs_table"
  workgroup = aws_athena_workgroup.this.name
    database = aws_athena_database.nginx.name
    query = templatefile("./aws/sql/create_table_sql.tpl", {
        athena_database_name = "${aws_athena_database.nginx.name}"
        athena_table_name = "nginx_logs"
        log_s3_path = "s3://${aws_s3_bucket.fluentd_bucket.bucket}/nginx/logs"
    })
}