data "google_project" "project" {}



module "project_services" {
  source                      = "terraform-google-modules/project-factory/google//modules/project_services"
  version                     = "~>15.0"
  disable_services_on_destroy = false
  project_id                  = data.google_project.project.project_id
  enable_apis                 = true
  providers = {
    google-beta = google-beta
  }
  activate_apis = [
    "bigquery.googleapis.com",
    "serviceusage.googleapis.com",
    "run.googleapis.com",
    "pubsub.googleapis.com",
    "iam.googleapis.com"
  ]
}

# Enable Pub/Sub API
resource "google_project_service" "pubsub_api" {
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

resource "google_cloud_run_v2_service" "app" {
  name     = "sample-app"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = "asia-northeast1-docker.pkg.dev/${data.google_project.project.project_id}/cloudrun-data-flow-sample-app/app"
      ports {
        container_port = 8080
      }
      env {
        name  = "PROJECT_ID"
        value = data.google_project.project.project_id
      }

      env {
        name  = "TOPIC_NAME"
        value = var.topic_name
      }
    }

    service_account = google_service_account.cloud_run_sa.email
  }




  depends_on = [module.project_services]

}


resource "google_cloud_run_service_iam_binding" "noauth" {
    location = google_cloud_run_v2_service.app.location
    service = google_cloud_run_v2_service.app.name
    role    = "roles/run.invoker"
    members = ["allUsers"]
}

resource "google_service_account" "cloud_run_sa" {
  account_id   = "cloud-run-sa"
  display_name = "Cloud Run Service Account"
}

// google_project_iam_bindingはproject単位で影響が及ぶため、roleを指定されていないmemberが持っていると、そのroleが削除されるらしい
// https://zenn.dev/ptiringo/articles/7dd246fcaa73da19d5fb
// 例えばサービスエージェントのroleが削除されたりすると影響が大きい

resource "google_project_iam_member" "cloud_run_sa_policy" {
  project = data.google_project.project.project_id
  role    = "roles/pubsub.publisher"
  member  = google_service_account.cloud_run_sa.member
}

resource "google_pubsub_topic" "topic" {
  name    = var.topic_name

  depends_on = [module.project_services]
}

resource "google_project_iam_member" "viewer" {
  project = data.google_project.project.project_id
  role   = "roles/bigquery.metadataViewer"
  member = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "editor" {
  project = data.google_project.project.project_id
  role   = "roles/bigquery.dataEditor"
  member = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}


resource "google_bigquery_dataset" "sample_dataset" {
    dataset_id = "sample_dataset"
    location = "asia-northeast1"
    depends_on = [module.project_services]
}

resource "google_bigquery_table" "sample_table" {
    dataset_id = google_bigquery_dataset.sample_dataset.dataset_id
    table_id = "sample_table"
    schema = jsonencode(
        [
        {
            "name": "Key",
            "type": "STRING",
            "mode": "REQUIRED"
        },
        {
            "name": "Value",
            "type": "INTEGER",
            "mode": "REQUIRED"
        }
        ]
    )
}

resource "google_pubsub_subscription" "example" {
  name  = "example-subscription"
  topic = google_pubsub_topic.topic.id

  bigquery_config {
    table = "${google_bigquery_table.sample_table.project}.${google_bigquery_table.sample_table.dataset_id}.${google_bigquery_table.sample_table.table_id}"
    use_table_schema = true
  }

  depends_on = [google_project_iam_member.viewer, google_project_iam_member.editor]
}
