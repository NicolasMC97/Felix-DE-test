external_tables = {

  customers = {
    local_file    = "./files/customers.csv"
    gcs_path      = "data/customers.csv"
    source_format = "CSV"
  }

  sales = {
    local_file    = "./files/sales.csv"
    gcs_path      = "data/sales.csv"
    source_format = "CSV"
  }

  transactions = {
    local_file    = "./files/transactions.csv"
    gcs_path      = "data/transactions.csv"
    source_format = "CSV"
  }
}