variable "external_tables" {
  description = "Tablas externas de BigQuery"

  type = map(object({
    local_file        = string
    gcs_path          = string
    source_format     = string
    skip_leading_rows = optional(number, 1)
  }))
}