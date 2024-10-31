terraform {
  required_version = "~>1.9.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.5.0"
    }
  }
}

provider "google-beta" {
  credentials = file("service_account.json")
  project     = var.google_project_id
  region      = var.google_region
  zone        = "${var.google_region}a"
}