resource "aws_sagemaker_code_repository" "this" {
  code_repository_name = "my-notebook-instance-code-repo"

  git_config {
    repository_url = "https://github.com/KatHaruto/terraform-practice.git"
    branch        = "main"
  }
}

resource "aws_sagemaker_notebook_instance" "ni" {
  name                    = "graphrag-notebook-instance"
  role_arn                = aws_iam_role.notebook.arn
  instance_type           = "ml.t2.medium"
  default_code_repository = aws_sagemaker_code_repository.this.code_repository_name
}

resource "aws_sagemaker_notebook_instance_lifecycle_configuration" "autostop" {
    name = "graphrag-notebook-instance-lifecycle-config"
    on_start = filebase64("sagemaker/lifecycle_configuration/auto-stop-idle/on-start.sh")
}
resource "aws_iam_role" "notebook" {
    name = "graphrag-notebook-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "sagemaker.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    })
}

resource "aws_iam_role_policy_attachments_exclusive" "notebook" {
    role_name = aws_iam_role.notebook.name
    policy_arns = [
        "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess",
        "arn:aws:iam::aws:policy/AmazonS3FullAccess",
        "${aws_iam_policy.notebook.arn}"
    ]
}

resource "aws_iam_policy" "notebook" {
    name = "graphrag-notebook-policy"
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Action = [
                    "bedrock:*"
                ],
                Resource = [
                    "*"
                ]
            },
            {
                Effect = "Allow",
                Action = [
                    "neptune-db:*"
                ],
                Resource = [
                    "*"
                ]
            }
        ]
    })
  
}