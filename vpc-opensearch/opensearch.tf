locals {
  opensearch_domain_name = "opensearch"
  foward_port            = 10443
}

resource "aws_iam_service_linked_role" "main" {
  aws_service_name = "opensearchservice.amazonaws.com"
}

resource "aws_security_group_rule" "inboud_bastion" {
  security_group_id        = aws_security_group.opensearch.id
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "inboud_lambda" {
  security_group_id        = aws_security_group.opensearch.id
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ingest-to-opensearch-lambda-sg.id
}


resource "aws_security_group" "opensearch" {
  name        = "${local.opensearch_domain_name}-sg"
  description = "Managed by Terraform"
  vpc_id      = module.vpc.vpc_id


  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_cloudwatch_log_group" "opensearch_es_application_log_group" {
  name              = "/aws/opensearch/${local.opensearch_domain_name}-es-application-logs"
  retention_in_days = 14
}


resource "aws_cloudwatch_log_group" "opensearch_index_slow_log_group" {
  name              = "/aws/opensearch/${local.opensearch_domain_name}-index-slow-logs"
  retention_in_days = 14
}


resource "aws_cloudwatch_log_group" "opensearch_search_slow_log_group" {
  name              = "/aws/opensearch/${local.opensearch_domain_name}-search-slow-logs"
  retention_in_days = 14
}


resource "aws_cloudwatch_log_resource_policy" "opensearch_es_application_log" {
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "es.amazonaws.com"
        }
        Action = ["logs:PutLogEvents", "logs:CreateLogStream"]
        Resource = ["${aws_cloudwatch_log_group.opensearch_es_application_log_group.arn}:*",
          "${aws_cloudwatch_log_group.opensearch_index_slow_log_group.arn}:*",
          "${aws_cloudwatch_log_group.opensearch_search_slow_log_group.arn}:*"
        ]
      }
    ]
  })
  policy_name = "opensearch-cloudwatch-es-application-log-policy"
}



resource "aws_opensearch_domain" "opensearch_domain" {
  domain_name    = local.opensearch_domain_name
  engine_version = "OpenSearch_2.13"

  cluster_config {
    instance_type          = "t3.medium.search"
    instance_count         = 1
    zone_awareness_enabled = false
    warm_enabled           = false

  }

  vpc_options {
    subnet_ids = [
      module.vpc.private_subnets[0]
    ]

    security_group_ids = [aws_security_group.opensearch.id]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_es_application_log_group.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_index_slow_log_group.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_search_slow_log_group.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }


  depends_on = [aws_iam_service_linked_role.main]
}



# https://qiita.com/docdocdoc/items/549dad29693657d9f368
# ロールマッピングしていてもドメインアクセスポリシーで明示的に拒否してしまっていた場合（②）はAPI操作ができない
# ロールマッピングしていなくてもドメインアクセスポリシーで明示的に許可されていれば（①にするか、③で指定）API操作ができる


data "aws_iam_policy_document" "main" {
  statement {
    effect = "Allow"
    actions = [
      "es:*"
    ]

    // principals {
    //  type        = "AWS"
    //  identifiers = [aws_lambda_function.main.role]
    // }

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      "${aws_opensearch_domain.opensearch_domain.arn}/*"
    ]
  }
}

resource "aws_opensearch_domain_policy" "main" {
  domain_name     = aws_opensearch_domain.opensearch_domain.domain_name
  access_policies = data.aws_iam_policy_document.main.json

}

resource "aws_s3_bucket" "opensearch_packages" {
  bucket = "opensearch-packages-bucket"
}

resource "aws_s3_object" "userdict" {
  bucket = aws_s3_bucket.opensearch_packages.bucket
  key    = "userdict.txt"
  source = "${path.root}/opensearch-settings/userdict.txt"
  etag   = filemd5("${path.root}/opensearch-settings/userdict.txt")
}

resource "aws_s3_object" "synonyms" {
  bucket = aws_s3_bucket.opensearch_packages.bucket
  key    = "synonyms.txt"
  source = "${path.root}/opensearch-settings/synonyms.txt"
  etag   = filemd5("${path.root}/opensearch-settings/synonyms.txt")
}

resource "aws_opensearch_package" "userdict" {
  package_name = "userdict-txt"
  package_source {
    s3_bucket_name = aws_s3_bucket.opensearch_packages.bucket
    s3_key         = aws_s3_object.userdict.key
  }
  package_type = "TXT-DICTIONARY" // PackageType_Values() -> enum{"TXT-DICTIONARY", "ZIP-PLUGIN"}
}

resource "aws_opensearch_package" "synonyms" {
  package_name = "synonyms-txt"
  package_source {
    s3_bucket_name = aws_s3_bucket.opensearch_packages.bucket
    s3_key         = aws_s3_object.synonyms.key
  }
  package_type = "TXT-DICTIONARY"

  lifecycle {
    replace_triggered_by = [aws_s3_object.synonyms.etag]
  }
}

resource "aws_opensearch_package_association" "userdict_association" {
  package_id  = aws_opensearch_package.userdict.id
  domain_name = aws_opensearch_domain.opensearch_domain.domain_name
}

resource "aws_opensearch_package_association" "synonyms_association" {
  package_id  = aws_opensearch_package.synonyms.id
  domain_name = aws_opensearch_domain.opensearch_domain.domain_name
}


provider "opensearch" {
  url                = "https://localhost:${local.foward_port}"
  host_override      = aws_opensearch_domain.opensearch_domain.endpoint
  aws_profile        = var.aws_profile // for local
  opensearch_version = "2.13"
  insecure           = true
  healthcheck        = false
}


resource "opensearch_index" "personnel" {
  name               = "sampel_index"
  number_of_shards   = "1"
  number_of_replicas = "0"
  index_knn          = true

  analysis_tokenizer = jsonencode({
    kuromoji_user_dict_tokenizer = {
      type            = "kuromoji_tokenizer"
      mode            = "search"
      user_dictionary = "analyzers/${aws_opensearch_package.userdict.id}"
    }

  })

  analysis_filter = jsonencode({
    synonym_filter = {
      type          = "synonym"
      synonyms_path = "analyzers/${aws_opensearch_package.synonyms.id}"
      updateable    = true
    }

  })

  analysis_analyzer = jsonencode({
    my_kuromoji_analyzer = {
      type        = "custom"
      char_filter = ["icu_normalizer"]
      tokenizer   = "kuromoji_tokenizer"
      filter      = ["kuromoji_part_of_speech"]
    }

    my_search_analyzer = {
      type        = "custom"
      char_filter = ["icu_normalizer"]
      tokenizer   = "kuromoji_tokenizer"
      filter      = ["kuromoji_part_of_speech", "synonym_filter"]

    }
  })

  mappings = file("${path.root}/opensearch-settings/sample-index.json")

  lifecycle {
    ignore_changes = [mappings]
  }

  # depends_on = [null_resource.create_index]
}