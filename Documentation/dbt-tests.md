# dbt tests: staging layer

Results of `dbt build --select staging` run on 2026-10-06 against `felix-technical-test.felix_dataset` (target `dev`). Purpose: record which tests fail or warn, why, and what was decided. See also [data-relationship-validation.md](data-relationship-validation.md) for the cross-table checks.

## Test inventory

- **Generic tests** (`models/staging/_models.yml`): `not_null`, `unique`, `accepted_values` and `relationships` on the three staging models.
- **Singular tests** (`tests/`):
  - `assert_receipts_amounts_valid`: consistency of the receipt amounts.
  - `assert_payments_amount_non_negative`: payments must not be negative.
  - `assert_payment_amount_matches_receipt`: payment amount equals `amount_charged` + `fee` for payments with a single receipt (tolerance 0.01 USD).

## Latest run

3 models and 48 tests: 42 passed, 5 warnings, 1 error (the error was downgraded to a warning afterwards, see below).

| Test | Severity | Failing rows | Cause |
|---|---|---|---|
| `assert_receipts_amounts_valid` | error, now warn | 2,955 before the fix, 2 after | Rule too strict, see finding 1 |
| `not_null` `disbursements.amount_local` | warn | 568 | Disbursements that never got an amount, see finding 2 |
| `not_null` `disbursements.destination_country_code` | warn | 137 | Same population as above, see finding 2 |
| `relationships` `receipts.disbursement_id` to disbursements | warn | 185 | Broken foreign key, see finding 3 |
| `assert_payments_amount_non_negative` | warn | 1 | Incomplete payment, see finding 4 |
| `assert_payment_amount_matches_receipt` | warn | 766 | Amount mismatch, see finding 5 |

## Findings

### 1. `assert_receipts_amounts_valid`: zero charge covered by a promotion

The test required `amount_charged_usd > 0`. Of 743,948 receipts, 2,953 have `amount_charged_usd = 0`.

- 2,952 of them have `promotion_amount_usd > 0` (average about 149 USD): the promotion paid for the whole transfer.
- They have a positive `destination_amount_local` and a valid `exchange_rate`, so the money was sent. They are valid transactions.
- 97% are SUCCESSFUL card payments. The rest are Apple Pay, wallet or REFUNDED. They are spread from January to September 2026, so this is not a one-off incident.

**Decision:** the rule now accepts `amount_charged_usd = 0` only when `promotion_amount_usd > 0`. A negative charge is always flagged. Severity set to `warn`.

Two real anomalies remain, both look like source data problems:

| Receipt (prefix) | Problem |
|---|---|
| `b70f9f48…` | `amount_charged_usd` = -522.99 with `destination_amount_local` = 8,944. Possibly a refund or chargeback loaded as a negative charge. Payment `0d23c23a…`. |
| `b897b10a…` | `amount_charged_usd` = 1 but `destination_amount_local` = 0, with exchange rate 17.26. Payment `0a58ba23…`. |

### 2. Disbursements with null `amount_local` or `destination_country_code`

| Status | `amount_local` null | `destination_country_code` null |
|---|---|---|
| FAILED | 566 | 135 |
| PENDING | 2 | 2 |

- All 137 rows with a null country also have a null `amount_local` and an empty `destination_currency`.
- These are disbursements that were never calculated, so nulls are expected for FAILED and PENDING.
- The other 431 FAILED rows with a null amount do have a country.

**Decision:** keep both tests as `warn`. In the marts, exclude these rows or handle them separately.

### 3. Receipts whose `disbursement_id` does not exist in disbursements

- 185 receipts (170 SUCCESSFUL and 15 REFUNDED payments), created between January and September 2026.
- They are also missing in the raw tables, so the staging deduplication is not the cause.
- The reverse direction is clean: every disbursement has a receipt.
- These are successful payments with a disbursement that never reached the disbursements table.

**Risk:** an `inner join` between receipts and disbursements in the marts drops these 185 receipts. Use a `left join`, or raise it with the source owner.

**Decision:** keep as `warn`.

### 4. `assert_payments_amount_non_negative`

- 1 row: a payment in STARTED status with `amount_usd` = -0.90 and no payment method.
- It is an incomplete payment with a residual value. Harmless if the analysis only uses SUCCESSFUL payments.

**Decision:** keep as `warn`.

### 5. `assert_payment_amount_matches_receipt`

766 of 715,012 payments with a single receipt (0.1%) do not match `amount_charged + fee`: 755 SUCCESSFUL and 11 REFUNDED. Two patterns dominate:

| Pattern | Payments | Likely cause |
|---|---|---|
| Payment is higher by 2.99 (other common gaps: 4.98, 6.49, 5.99) with `fee_usd` = 0 | about 345 for the 2.99 gap | A fee or extra charge on the payment that the receipt does not record in `fee_usd` |
| Payment is lower by 1.00 with an average fee of 6.89 | 137 | A fixed 1 USD discount that the receipt does not reflect |

The promotion amount does not explain the gap: no mismatched payment matches once it is added.

**Decision:** keep as `warn`. Confirm with the business how the payment amount is calculated before turning it into a rule or a model transformation.

## Summary of actions

| Finding | Action |
|---|---|
| 1 | Test rule corrected, severity `warn`, 2 anomalies to review with the source owner |
| 2 | Expected, filter in the marts |
| 3 | Use `left join` in the marts, report to the source owner |
| 4 | Expected, ignore or filter |
| 5 | Open question for the business |
