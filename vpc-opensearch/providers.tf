terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }

    opensearch = {
      source  = "opensearch-project/opensearch"
      version = ">=2.2.0"
    }
  }
}
 