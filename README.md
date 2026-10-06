# Felix-DE-test
Repo to develop Data Engineer Manager test to Felix

## Architecture

![Architecture diagram](Documentation/architecture.svg)

| Layer | Tool | Location |
|---|---|---|
| Infrastructure | Terraform | `IAC_google/` |
| Raw | GCS + BigQuery external tables | `felix_dataset` |
| Staging | dbt views (dedup, rename, status normalization) | `dbt_felix` |
| Intermediate / marts | dbt | pending |

Detailed notes (IAC, schema findings, dbt models and tests): [`Documentation/project-progress.md`](Documentation/project-progress.md).

## Infrastructure as Code (`IAC_google/`)

Terraform that deploys the landing layer on GCP (`felix-technical-test`):

- **Cloud Storage:** bucket `landing_bucket_felix_test` with the CSV files under `data/`.
- **BigQuery:** dataset `felix_dataset` with one external table per CSV (`payments`, `receipts`, `disbursements`) and an explicit schema from `schemas/*.json`.

Files and external tables are created with `for_each` over `var.external_tables`. To add a table, add an entry in `terraform.tfvars`, a schema in `schemas/` and the CSV in `files/`.

```bash
cd IAC_google
terraform init
terraform apply
terraform destroy
```

Notes:
- **Large CSVs are not versioned.** Copy the full files to `IAC_google/files/` before `terraform apply`; they are git-ignored and uploaded to GCS. Samples (10 rows) are in `IAC_google/files/samples/`.
- `force_destroy = true` and `deletion_protection = false` are for a test environment only.
- `force_destroy` is read from state: run `terraform apply` before `terraform destroy` if you change it.
- Local state is excluded via `.gitignore`.

## dbt (`DBT/`)

Staging views over the raw tables, with generic and singular tests. Requires a BigQuery profile named `default` in `~/.dbt/profiles.yml`.

```bash
cd DBT
dbt debug
dbt build --select staging
```
