# Storage Bucket
resource "google_storage_bucket" "my_bucket" {
  name                        = "landing_bucket_felix_test"
  location                    = "US"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = true
}

# Load data to Storage Bucket
resource "google_storage_bucket_object" "csv_files" {
  for_each = var.external_tables
  name     = each.value.gcs_path
  bucket   = google_storage_bucket.my_bucket.name
  source   = each.value.local_file
}
