external_tables = {

  disbursements = {
    local_file    = "./files/disbursements.csv"
    gcs_path      = "data/disbursements.csv"
    source_format = "CSV"
  }

  payments = {
    local_file    = "./files/payments.csv"
    gcs_path      = "data/payments.csv"
    source_format = "CSV"
  }

  receipts = {
    local_file    = "./files/receipts.csv"
    gcs_path      = "data/receipts.csv"
    source_format = "CSV"
  }
}