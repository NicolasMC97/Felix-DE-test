# Relationship validation: payments, receipts, disbursements

Validation run against the raw BigQuery tables (`felix-technical-test.felix_dataset`) on 2026-10-06, after deduplicating by `id` exactly as the staging models do. Purpose: decide the grain of the fact tables before building the dimensional model.

## Entity relationship

```
payments (1) ──< receipts (N) >── (1) disbursements
  id              payment_id          id
                  disbursement_id
```

- `receipts` is the bridge table: one row per payout attempt of a payment.
- `receipts.disbursement_id` is unique, so receipt and disbursement are 1:1.
- A payment has 0..8 receipts. More than one means the payout was retried.

## Results

| # | Check | Result | Verdict |
|---|---|---|---|
| 1 | Duplicate ids (raw vs deduplicated) | payments 788,976 / disbursements 743,763 / receipts 743,948, identical in both | No duplicates in the current extract. Dedup in staging is a safeguard. |
| 2 | Receipts per payment | 0: 60,749 / 1: 715,012 / 2: 11,259 / 3: 1,540 / 4: 312 / 5: 79 / 6: 21 / 7: 3 / 8: 1 | Payment to receipt is 1:N. 13,215 payments (1.8% of those with receipts) were retried. |
| 3 | Receipts per disbursement | Always 1 | Receipt to disbursement is 1:1. |
| 4 | Receipts with no payment | 0 | OK |
| 4 | Receipts with null `payment_id` or `disbursement_id` | 0 | OK |
| 4 | Disbursements with no receipt | 0 | OK |
| 4 | Receipts whose `disbursement_id` is missing in disbursements | 185 (170 SUCCESSFUL, 15 REFUNDED payments) | Broken FK, see findings. |
| 5 | Payments with no receipt | 60,749: FAILED 58,684, SUCCESSFUL 1,961, REFUNDED 86, PENDING_USER_ACTION 17, STARTED 1 | Expected for FAILED. The rest need a rule, see findings. |
| 6 | Payments with receipt by status | SUCCESSFUL 722,091 / REFUNDED 6,133 / FAILED 3 | 3 FAILED payments have a receipt, an anomaly. |
| 8 | `user_id` consistent across the 3 tables | 0 mismatches payment vs receipt and receipt vs disbursement | OK |
| 8 | `beneficiary_id` under more than one user | 0 | OK |
| 10 | Receipt created before its payment | 0 | OK |
| 10 | Disbursement created more than 1 min before its receipt | 753 | Minor ordering noise. |
| 10 | Disbursement `updated_at` < `created_at` | 18 | Data quality. |
| 10 | Disbursement `updated_at` null | 816 | Data quality. |

### Amount reconciliation (payment amount = `amount_charged` + `fee`)

| Group | Payments | Equal to last receipt | Equal to sum of all receipts | Neither |
|---|---|---|---|---|
| 1 receipt | 715,012 | 714,245 | 714,245 | 767 |
| 2+ receipts | 13,215 | 13,096 | 8 | 118 |

- With retries, every attempt repeats the full amount: in 13,100 of 13,215 retried payments all receipts carry the same `amount_charged + fee`.
- Summing receipts therefore double counts. The sum of all receipts is **247.8M USD** versus **240.4M USD** from payments that have a receipt (about **+3.1%** inflated).
- 957 payments differ from the last receipt by 1 cent or more (0.13%). Differences range from -40 to +523 USD, and one payment has a non-positive amount. See finding 7.

### Final payout status of the last attempt

- SUCCESSFUL payments end mostly in PAID, Success or COMPLETED (720,619 of 722,091).
- REFUNDED payments end mostly in CANCELLED, FAILED or REJECTED.
- Some SUCCESSFUL payments have a last attempt still in PAYABLE (438), WIRE_RELEASED (372), IN_PROGRESS (312), or in FAILED, Failed, CANCELLED or REJECTED (about 190). These are in flight or inconsistent.
- Disbursement status mixes casing (`Success`, `Failed`, `Pending`). Staging uppercases it and maps it to `status_group`.

### Disputes

525 of 724,052 SUCCESSFUL payments have `has_dispute_chargeback` = true (0.07%). Only 1 REFUNDED payment has it, and no FAILED payment has it.

## Findings and decisions for the model

1. **The payment is the grain for money.** TPV, fees and promotions come from one receipt per payment, never from summing receipts.
2. **Pick the last receipt as the final attempt.** Order by `created_at` desc. It matches the payment amount in 13,096 of 13,215 retried cases. Add `attempt_number` and `attempts_count` in `int_transfers`.
3. **`fct_transfers`: one row per payment that has a receipt.** Payments with no receipt stay in `fct_payments` only.
4. **`fct_disbursements`: one row per attempt**, with `attempt_number`, so retry and provider metrics are computed at the right grain.
5. **185 receipts point to a disbursement that does not exist.** Use a left join to disbursements and keep the row, with null payout status. Add a `relationships` test with `severity: warn`.
6. **1,961 SUCCESSFUL payments have no receipt**, almost all from June to September 2026 (29, 148, 733, 1,051 per month), growing toward the end of the extract. Likely transfers not yet created. Flag them as `payout_not_created` and monitor.
7. **Amount mismatches: 957 payments (0.13% of 728,227 transfers)** when comparing the payment amount with the last receipt (`amount_charged + fee`, rounded to cents). They are kept as columns in `trf_transfers` (`amount_diff_usd`, `has_amount_mismatch`, `amount_mismatch_type`) and monitored in a data quality mart, not corrected. Breakdown: FEE_NOT_RECORDED 731 (receipt fee is 0, +2,687 USD), RECEIPT_HIGHER 200 (-198 USD), OTHER 25, NEGATIVE_OR_ZERO_AMOUNT 1 (payment of 0 USD with a receipt of -522.99 USD). Promotions do not explain any case.
8. **3 FAILED payments with receipts** are excluded from revenue metrics, and a test should alert if the count grows.

## Tests to add

- `relationships`: `receipts.payment_id` to `payments`, `severity: error`.
- `relationships`: `receipts.disbursement_id` to `disbursements`, `severity: warn` (185 known).
- `unique` on `receipts.disbursement_id`.
- Singular test: payment amount equals last receipt `amount_charged + fee`, `severity: warn`.
- Singular test: no FAILED payment has a receipt, `severity: warn`.
- `fct_transfers`: `unique` and `not_null` on `payment_id`, and TPV reconciled against `stg_remittances__payments`.

## Reproducing

Queries were run with `bq query --project_id=felix-technical-test`. All use a base CTE that deduplicates each table by `id` (latest `updated_at` for payments and disbursements, latest `created_at` for receipts).

## Slowly changing dimensions

The data is a static extract: no new data will arrive and the source keeps no history of attributes, only the latest row state. Every dimension is therefore modeled as SCD Type 1. Snapshots (SCD Type 2) are not implemented because they only record changes from their first run onward and would never see a change here. In a live pipeline two snapshots would be worth adding:

- `dim_user`: snapshot of `trf_user_activity` to keep the history of the activity segment.
- Disbursement status: snapshot of `stg_remittances__disbursements` on `updated_at`, to measure how long a payout stays in states like ON_HOLD (the source overwrites the status).
