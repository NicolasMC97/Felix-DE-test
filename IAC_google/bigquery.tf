# Bigquery API
resource "google_project_service" "bigquery_api" {
  service            = "bigquery.googleapis.com"
  disable_on_destroy = false
}

# Bigquery Dataset
resource "google_bigquery_dataset" "felix_dataset" {
  dataset_id  = "felix_dataset"
  location    = "US"
  description = "Felix Dataset"
  depends_on = [
    google_project_service.bigquery_api
  ]
}

# Bigquery Tables
resource "google_bigquery_table" "external_tables" {
  for_each            = var.external_tables
  table_id            = each.key
  dataset_id          = google_bigquery_dataset.felix_dataset.dataset_id
  deletion_protection = false

  depends_on = [google_storage_bucket_object.csv_files]

  external_data_configuration {
    autodetect    = true
    source_format = each.value.source_format
    source_uris   = ["gs://${google_storage_bucket.my_bucket.name}/${each.value.gcs_path}"]
  }
}


