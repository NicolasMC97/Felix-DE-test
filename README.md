# Felix-DE-test
Repo to develop Data Engineer Manager test to Felix

## Infrastructure as Code (`IAC_google/`)

Terraform that deploys the landing layer on GCP (`felix-technical-test`):

- **Cloud Storage:** bucket `landing_bucket_felix_test` with the CSV files under `data/`.
- **BigQuery:** dataset `felix_dataset` with one external table per CSV (`customers`, `sales`, `transactions`).

Files and external tables are created with `for_each` over `var.external_tables`. To add a table, add an entry in `terraform.tfvars` and put the CSV in `files/`.

```bash
cd IAC_google
terraform init
terraform apply
terraform destroy
```

Notes:
- `force_destroy = true` and `deletion_protection = false` are for a test environment only.
- `force_destroy` is read from state: run `terraform apply` before `terraform destroy` if you change it.
- Local state is excluded via `.gitignore`.
