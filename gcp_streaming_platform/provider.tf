terraform {
  required_version = "~> 1.9.3"
  

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.39.1"
    }
  }
}

provider "google-beta" {
  credentials = file("service_account.json")
  project     = var.project_id
  region      = var.region
  zone        = "${var.region}a"
}