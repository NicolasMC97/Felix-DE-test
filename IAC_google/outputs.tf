output "bucket_url" {
  description = "URL del bucket de landing"
  value       = google_storage_bucket.my_bucket.url
}

output "dataset_id" {
  description = "ID del dataset de BigQuery"
  value       = google_bigquery_dataset.felix_dataset.dataset_id
}

output "external_table_ids" {
  description = "IDs de las tablas externas de BigQuery"
  value       = { for k, t in google_bigquery_table.external_tables : k => t.id }
}
