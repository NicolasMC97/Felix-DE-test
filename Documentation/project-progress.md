# Project Progress

Take-home assessment for the Data Engineering Manager role at Félix. A remittance is a **payment** made by the sender plus a **disbursement** to the beneficiary; **receipts** link both. This document records what has been built so far.

Contents:
1. [Infrastructure as Code](#1-infrastructure-as-code-iac_google)
2. [Dataset schema definition and initial findings](#2-dataset-schema-definition-and-initial-findings)
3. [dbt models and first tests](#3-dbt-models-and-first-tests-dbt)
4. [Pending work](#4-pending-work)

---

## 1. Infrastructure as Code (`IAC_google/`)

Terraform (provider `google ~> 8.0`) provisions the raw landing layer in GCP project `felix-technical-test`.

### Resources

| Resource | Purpose |
|---|---|
| `google_storage_bucket.my_bucket` | Landing bucket `landing_bucket_felix_test` (US, uniform access) |
| `google_storage_bucket_object.csv_files` | One CSV per table under `data/`, created with `for_each` |
| `google_project_service.bigquery_api` | Enables the BigQuery API |
| `google_bigquery_dataset.felix_dataset` | Raw dataset `felix_dataset` (US) |
| `google_bigquery_table.external_tables` | One external table per CSV, with an explicit schema |

### Layout

| File | Content |
|---|---|
| `providers.tf` | `terraform` block and provider |
| `storage.tf` | Bucket and CSV objects |
| `bigquery.tf` | API, dataset and external tables |
| `variables.tf` / `terraform.tfvars` | `external_tables` map (`local_file`, `gcs_path`, `source_format`, `skip_leading_rows`) |
| `outputs.tf` | `bucket_url`, `dataset_id`, `external_table_ids` |
| `schemas/*.json` | Column name, type, mode and description per table |

### Design decisions

- **Single source of truth:** one variable (`external_tables`) drives both the GCS objects and the BigQuery tables. Adding a table means adding one block in `terraform.tfvars`, one JSON in `schemas/` and one CSV in `files/`.
- **Execution order** is decided by the dependency graph, not by file order. Tables depend on the dataset, the bucket and (explicitly) on the CSV objects, so a table is never created before its file exists.
- **Explicit schema** (`autodetect = false`) with `csv_options.skip_leading_rows = 1`. Autodetect infers wrong types on large files (it inferred `INT64` for decimal amounts).
- **`moved` blocks** were used when renaming resources so Terraform did not destroy and recreate them.
- **Test-environment settings:** `force_destroy = true` (bucket) and `deletion_protection = false` (tables) so `terraform destroy` works. Review for production. `force_destroy` is read from state, so run `terraform apply` before `terraform destroy` if you change it.

### Large files

The full CSVs (~650 MB; `receipts.csv` alone is ~144 MB) are **not versioned**: GitHub rejects files above 100 MB.

- `IAC_google/files/*.csv` is git-ignored. Copy the full files there; `terraform apply` uploads them to GCS.
- `IAC_google/files/samples/` holds 10-row samples that are versioned, so a fresh clone can still be exercised.
- If `files/*.csv` contains samples when `terraform apply` runs, it **overwrites** the full files already in the bucket. Always copy the full files first.

### Repository hygiene

`.gitignore` excludes Terraform state (`*.tfstate*`), `.terraform/`, plans, crash logs, credentials (`*.pem`, `*.key`, `service-account*.json`) and the large CSVs. `.terraform.lock.hcl` **is** versioned to pin provider versions.

---

## 2. Dataset schema definition and initial findings

Profiling was done on the full files (`payments` 788,976 rows, `receipts` 743,948, `disbursements` 743,763; data from 2026-01-01 to 2026-09-22). The result is the schema in `IAC_google/schemas/`.

### Data model

```
payments (1) ──< receipts >── (1) disbursements
   payment_id        │       disbursement_id
                     └── user_id, beneficiary_id
```

- **payments** — one charge to the sender, in USD.
- **disbursements** — one payout attempt, in the destination (local) currency.
- **receipts** — link a payment to a disbursement attempt; carries fee, FX rate and delivered amount.

### Business rules inferred from the data

| Rule | Evidence |
|---|---|
| `payments.amount = receipts.amount_charged + fee` | holds for 99.9% of single-receipt payments |
| `destination_amount = (amount_charged + promotion_amount) × exchange_rate` | holds for 99.99% of promotion rows |
| Promotions are a bonus funded by the company, not charged to the sender | `payment = charged + fee`, promotion only affects the delivered amount |
| A payment can have several receipts: they are **payout retries** | e.g. 3 receipts for one payment: 2 `FAILED` (PROVIDER 8, 12), 1 `COMPLETED` (PROVIDER 5) |
| `disbursements.amount` is in local currency | median 2.6k, max 11.7M; equals `destination_amount` in ~78% of rows (small FX rounding otherwise) |

Retries matter: summing all receipts of a payment double counts money. Metrics must be built at payment level or on the successful disbursement only.

### Data quality findings

| # | Finding | Impact |
|---|---|---|
| 1 | `disbursements.status` mixes vocabularies and casing (`PAID`, `COMPLETED`, `Success`, `complete`; `FAILED`, `Failed`, `cancelled`) | Needs a normalized status in staging |
| 2 | 18 disbursements are `CANCELLED` while `raw_status` is `COMPLETED` / `PAID` | Open question: which field wins |
| 3 | `has_dispute_chargeback` merges disputes and chargebacks (526 rows, 0.07%) | Chargeback rate is an approximation |
| 4 | `payments.error_code` and `reason` are 100% null; `total_intents` is ~98% null | Dropped / flagged |
| 5 | Each `beneficiary_id` appears under a single `user_id` (554,117 beneficiaries) | "Users sending to the same beneficiary" clusters would be empty; the ID is likely hashed per user |
| 6 | 137 disbursements have null country and currency; 25 use `COSTA RICA` instead of `CR` | Cleaned in staging |
| 7 | 133 payments with amount 0 and one with -0.9 (`STARTED`) | Warning test |
| 8 | 60,749 payments have no receipt, almost all of the 58,687 `FAILED` | Expected |
| 9 | 568 disbursements with null amount (`FAILED` / `Pending`) | Warning test |
| 10 | ~185 receipts reference a `disbursement_id` missing from disbursements (0.03%) | Warning test |
| 11 | 7,472 receipts belong to `REFUNDED` payments whose disbursement was `CANCELLED`, `FAILED` or `REJECTED` | Interpreted as money returned to the sender |

### Column notes

- `payments.location_of_request_state_code` is only populated for `CASH` and `ACH` (US state).
- `disbursements.provider_status` is free text or numeric codes and null in ~78% of rows.
- `payer_destination_name` is the paying institution or network (e.g. `DESTINATION_17`); several payers operate under each `disbursement_provider`.
- All timestamps are UTC.

---

## 3. dbt models and first tests (`DBT/`)

### Sources and profile

- **Sources** (`models/srcs/_sources.yml`): `remittances.payments`, `.disbursements` and `.receipts`, pointing to `felix-technical-test.felix_dataset`. Column descriptions are generated from the Terraform JSON schemas. `id` has `unique` and `not_null` tests.
- **Profile**: `~/.dbt/profiles.yml` (outside the repo), BigQuery with a service account, target dataset `dbt_felix`, location `US`. `dbt debug` passes.

### Staging models (`models/staging/`, materialized as views)

| Model | Grain | Main transformations |
|---|---|---|
| `stg_remittances__payments` | one row per payment | dedup by id, rename (`amount_usd`), upper-case text, drop empty columns |
| `stg_remittances__disbursements` | one row per payout attempt | dedup, rename (`amount_local`, `provider`, `payer_name`), `COSTA RICA` → `CR`, **`status_group`** normalization |
| `stg_remittances__receipts` | one row per receipt | dedup, rename with units (`amount_charged_usd`, `fee_usd`, `destination_amount_local`) |

`status_group` maps the raw statuses to `COMPLETED`, `FAILED`, `CANCELLED`, `IN_PROGRESS`, `ON_HOLD`. Any unknown status becomes `UNMAPPED` so the `accepted_values` test fails when a new one appears.

> Assumptions to validate: `TRANSMITTED`, `WIRE_RELEASED` and `WIRE_CONFIRMED` are treated as `IN_PROGRESS`; `REJECTED` as `FAILED`.

### Tests

**Generic tests** (`_stg_remittances__models.yml`): `unique` and `not_null` on keys, `accepted_values` on status, method, country and currency, and `relationships` receipts → payments (error) and receipts → disbursements (warn). Known data issues use `severity: warn`.

**Singular tests** (`tests/`):

| Test | Rule | Severity |
|---|---|---|
| `assert_payments_amount_non_negative` | no negative payment amounts | warn |
| `assert_receipts_amounts_valid` | principal and rate > 0, fee and promotion ≥ 0 | error |
| `assert_payment_amount_matches_receipt` | payment = charged + fee for single-receipt payments | warn |

### First run

`dbt build --select staging`: 3 models, 48 tests → **43 passed, 4 warnings, 4 errors**.

- **Warnings** are the known data issues (findings 6, 7, 9, 10).
- **Errors** share one cause: the external tables still used `autodetect`, which inferred `INT64` for `amount_charged` and `promotion_amount`. The explicit schemas fix this once Terraform is applied.

---

## 4. Pending work

1. Copy the full CSVs to `IAC_google/files/`, `terraform apply` (recreates the 3 external tables with explicit schemas), then re-run `dbt build --select staging`.
2. Validate the status mapping and open questions (findings 2, 3, 5, 11).
3. Intermediate layer: payment ↔ receipt ↔ disbursement joined by business context, handling retries.
4. Marts for the requested metrics: total amount by month, users making up 50% of volume, recurring customers, providers by failed disbursements, beneficiary clusters, chargeback rate.
5. Materialize heavy models as tables: the raw layer is external tables, so each query re-reads the CSVs from GCS.
