
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