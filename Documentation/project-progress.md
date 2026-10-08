# Project Progress

Take-home assessment for the Data Engineering Manager role at Félix. A remittance is a **payment** made by the sender plus a **disbursement** to the beneficiary; **receipts** link both. This document records what has been built so far. KPIs and the business questions they answer: [business-questions-and-kpis.md](business-questions-and-kpis.md).

Contents:
1. [Infrastructure as Code](#1-infrastructure-as-code-iac_google)
2. [Dataset schema definition and initial findings](#2-dataset-schema-definition-and-initial-findings)
3. [dbt staging models and tests](#3-dbt-staging-models-and-tests-dbt)
4. [Data model: transformations, dimensions, facts and marts](#4-data-model-transformations-dimensions-facts-and-marts)
5. [Semantic layer](#5-semantic-layer-dbtmodelssemantic)
6. [Pending work](#6-pending-work)

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

## 3. dbt staging models and tests (`DBT/`)

### Sources and profile

- **Sources** (`models/srcs/_sources.yml`): `remittances.payments`, `.disbursements` and `.receipts`, pointing to `felix-technical-test.felix_dataset`. Column descriptions are generated from the Terraform JSON schemas. `id` has `unique` and `not_null` tests.
- **Profile**: `~/.dbt/profiles.yml` (outside the repo), BigQuery with a service account, target `dev` with dataset `dbt_dev_local`, location `US`. `dbt debug` passes.

### Staging models (`models/staging/`, materialized as views)

| Model | Grain | Main transformations |
|---|---|---|
| `stg_remittances__payments` | one row per payment | dedup by id, rename (`amount_usd`), upper-case text, drop empty columns |
| `stg_remittances__disbursements` | one row per payout attempt | dedup, rename (`amount_local`, `provider`, `payer_name`), `COSTA RICA` → `CR`, **`status_group`** normalization |
| `stg_remittances__receipts` | one row per receipt | dedup, rename with units (`amount_charged_usd`, `fee_usd`, `destination_amount_local`) |

`status_group` maps the raw statuses to `COMPLETED`, `FAILED`, `CANCELLED`, `IN_PROGRESS`, `ON_HOLD`. Any unknown status becomes `UNMAPPED` so the `accepted_values` test fails when a new one appears.

> Assumptions to validate: `TRANSMITTED`, `WIRE_RELEASED` and `WIRE_CONFIRMED` are treated as `IN_PROGRESS`; `REJECTED` as `FAILED`.

### Tests

**Generic tests** (`models/staging/_models.yml`): `unique` and `not_null` on keys, `accepted_values` on status, method, country and currency, and `relationships` receipts → payments (error) and receipts → disbursements (warn). Known data issues use `severity: warn`.

**Singular tests** (`tests/`):

| Test | Rule | Severity |
|---|---|---|
| `assert_payments_amount_non_negative` | no negative payment amounts | warn |
| `assert_receipts_amounts_valid` | principal and rate > 0, fee and promotion ≥ 0 | error |
| `assert_payment_amount_matches_receipt` | payment = charged + fee for single-receipt payments | warn |

### Staging test results

`dbt build --select staging` on the full data: 3 models, 48 tests, all passing except known source data issues, which are `warn`: negative payment amount, null `amount_local` and `destination_country_code` in disbursements, 185 receipts with a missing disbursement and payment amounts that do not match the receipt. The explicit schemas applied through Terraform fixed the earlier type errors (`INT64` inferred for decimal amounts). Detail and decisions per test: [dbt-tests.md](dbt-tests.md).

---

## 4. Data model: transformations, dimensions, facts and marts

Star schema built on the staging layer. Full description of every step: [data-modeling.md](data-modeling.md). Relationship checks that drove the design: [data-relationship-validation.md](data-relationship-validation.md).

![Dimensional model](images/dimensional-model.svg)

### What was built

| Layer | Folder | Models |
|---|---|---|
| Transformations | `models/transformations/` | `trf_payment_receipts` (one row per payout attempt), `trf_transfers` (one row per payment with receipt, money from the last receipt), `trf_user_activity` (one row per sender) |
| Dimensions | `models/dim/` | `dim_date`, `dim_corridor`, `dim_payment_method`, `dim_payment_status`, `dim_disbursement_status`, `dim_payout_provider`, `dim_user` |
| Facts | `models/fact/` | `fct_payments` (payment), `fct_disbursements` (payout attempt), `fct_transfers` (payment with receipt, accumulating snapshot) |
| Marts | `models/mart/` | `mart_finance_daily`, `mart_payment_conversion`, `mart_payout_performance`, `mart_user_cohorts`, `mart_user_daily`, `mart_risk`, `mart_data_quality` |
| Semantic layer | `models/semantic/` | 8 semantic models, 53 metrics and `metricflow_time_spine` (section 5) |

Transformations, dimensions, facts and marts are materialized as tables; staging stays as views. `mart_user_daily` (user x day, successful payments only) was added to answer user behavior per day. Shared macros: `generate_surrogate_key` and `date_key`.

### Key decisions

- **Retries and money.** A payment can have several receipts and every retry repeats the full amount, so summing receipts overstates TPV by about 3.1%. Money is read from the payment and the last receipt only (`fct_transfers`); payout metrics are read per attempt (`fct_disbursements`).
- **Amount rule.** `payment amount = amount_charged + fee` fails for 957 payments (0.13%), mostly a fee not recorded in the receipt (731, +2,687 USD). They stay in the facts with `has_amount_mismatch` and `amount_mismatch_type` and are monitored in `mart_data_quality`, not corrected.
- **Broken and missing links.** Receipts with a missing disbursement are kept with a left join; 1,961 successful payments without receipt are flagged `is_payout_not_created`.
- **No `dim_state`.** `location_of_request_state_code` is filled in 0.05% of payments (CASH 37%, ACH 2%, card 0%) and has dirty values, so it stays as a degenerate attribute.
- **SCD.** All dimensions are Type 1. The data is a static extract with no attribute history, so snapshots (Type 2) would never record a change. They are documented as the recommendation for a live pipeline.

### Results

TPV of successful transfers 237.69M USD, fee revenue 2.90M USD (take rate 1.22%), 722,091 successful transfers, 421,412 senders. Latest full `dbt build`: all models and tests of this layer pass. The dbt starter models in `models/example/` were removed.

### How the requested metrics map to the marts

| Metric | Where |
|---|---|
| Total amount by month | `mart_finance_daily`, summed by month |
| Behavior per user per day | `mart_user_daily` |
| Any KPI at any grain (country, method, provider, month) | semantic layer, section 5 |
| Recurring customers | `dim_user.is_repeat_user` and `mart_user_cohorts` |
| Providers by failed disbursements | `mart_payout_performance` |
| Chargeback rate | `mart_risk` (approximation, disputes and chargebacks are merged in the source) |
| Users making up 50% of volume | not built yet, see pending work |
| Beneficiary clusters | not built; each beneficiary belongs to a single user (finding 5) |

---

## 5. Semantic layer (`DBT/models/semantic/`)

KPIs are defined once as MetricFlow metrics so every tool computes them the same way. Metric catalog, dimensions and example queries: [semantic-layer.md](semantic-layer.md). The KPI catalog and the questions it answers: [business-questions-and-kpis.md](business-questions-and-kpis.md).

### What was built

| File | Content |
|---|---|
| `_semantic_models.yml` | Three fact semantic models (`transfers`, `payments`, `disbursements`) and five dimension ones (`users`, `corridors`, `payment_methods`, `payment_statuses`, `payout_providers`). Entities define the joins. |
| `_metrics.yml` | 53 metrics: revenue and volume, payments and conversion, payouts and delivery, customers, risk. |
| `metricflow_time_spine.sql` and `_time_spine.yml` | Day-grain calendar over `dim_date`, required by MetricFlow. |

### Key decisions

- **Semantic models sit on facts and dimensions, not on marts.** Ratios (take rate, success rate, dispute rate) are recomputed from additive measures, so they stay correct at any grain. Marts cannot be re-aggregated without breaking ratios.
- **Money measures count successful payments only** (`if(is_successful_payment, ...)`), the same rule as `mart_finance_daily`; conversion and risk measures read `fct_payments` with every status.
- **Median delivery time** is an approximate percentile, the only kind BigQuery supports in MetricFlow.
- **Left out on purpose:** cumulative and month-offset metrics (MoM growth, cumulative TPV) because MetricFlow generates SQL that mixes `DATETIME` and `TIMESTAMP` and BigQuery rejects it. Retention by cohort stays in `mart_user_cohorts`.

### Validation

`dbt sl` needs a dbt Cloud project, so the layer is checked with the open-source MetricFlow CLI (`dbt-metricflow` with `dbt-core` 1.12 and `dbt-bigquery`). `mf validate-configs` passes against BigQuery (semantic models, dimensions, entities, measures and metrics, 0 errors). Queries reproduce the facts: monthly TPV adds up to 237.69M USD and the take rate is 1.22%. Commands are in the root README.

The project was renamed from `Felix-DE-test` to `felix_de_test` because MetricFlow rejects hyphens in the project name, and the unused `example` config was dropped from `dbt_project.yml`.

---

## 6. Pending work

1. Build the mart for the users that make up 50% of the volume (cumulative share of TPV by user, from `dim_user`).
2. Confirm the business rule behind the 957 amount mismatches and the open questions: status mapping assumptions (`TRANSMITTED`, `WIRE_RELEASED`, `WIRE_CONFIRMED` as in progress, `REJECTED` as failed), findings 2, 3, 5 and 11.
3. Staging models are views over external tables, so every query re-reads the CSVs from GCS. Materialize them as tables if query cost or latency matters.
4. `dim_date` has a fixed range (2026-01-01 to 2026-12-31); extend it or derive it from staging if new data arrives.
5. Semantic layer: migrate the YAML to the new dbt spec (dbt 2.0 warns that the legacy format is deprecated; `dbt-autofix` can help) and publish it through dbt Cloud so BI tools can query it.
6. Semantic layer: add the KPIs still marked as proposed in [business-questions-and-kpis.md](business-questions-and-kpis.md) (P90 and P95 delivery time, SLA compliance, customer lifetime value, per-user rankings) and re-add MoM growth and cumulative TPV once MetricFlow supports them on BigQuery.
7. For a live pipeline: add the two snapshots described in data-modeling.md (user activity segment and disbursement status), incremental loads and scheduling.
