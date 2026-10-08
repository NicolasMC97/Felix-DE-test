# Semantic layer

The semantic layer defines the KPIs once, as MetricFlow metrics, so every tool computes them the same way. It lives in `DBT/models/semantic/`. The KPI catalog and the business questions it answers are in [business-questions-and-kpis.md](business-questions-and-kpis.md); each KPI table there has a **Semantic metric** column that points to the metric names below.

Contents:
1. [Why a semantic layer next to the marts](#1-why-a-semantic-layer-next-to-the-marts)
2. [What is in it](#2-what-is-in-it)
3. [Metric catalog](#3-metric-catalog)
4. [Dimensions by metric family](#dimensions-by-metric-family)
5. [How to query it](#5-how-to-query-it)
6. [Example queries by question](#example-queries-by-question)
7. [Limits and what is not in the layer](#7-limits-and-what-is-not-in-the-layer)

---

## 1. Why a semantic layer next to the marts

| | Marts | Semantic layer |
|---|---|---|
| Built on | Facts and dimensions, one SQL model per grain | Facts and dimensions, metric definitions |
| Grain | Fixed (for example day x corridor x payment method) | Any: group by any reachable dimension |
| Ratios | Computed in the table for its grain, not additive | Recomputed from additive measures, correct at any grain |
| Best for | Dashboards that always read the same cut | Ad hoc questions and one shared definition across tools |

Both exist on purpose. A mart is cheap to read for a fixed dashboard; the semantic layer answers the cut nobody built a mart for, such as take rate by region and month.

Semantic models sit on the facts and dimensions, not on the marts. A mart cannot be re-aggregated without breaking its ratios (a take rate by month cannot be averaged from take rates by day).

## 2. What is in it

| File | Content |
|---|---|
| `_semantic_models.yml` | 3 fact semantic models (`transfers`, `payments`, `disbursements`) and 5 dimension ones (`users`, `corridors`, `payment_methods`, `payment_statuses`, `payout_providers`). Entities define the joins. |
| `_metrics.yml` | 53 metrics. |
| `metricflow_time_spine.sql`, `_time_spine.yml` | Day-grain calendar over `dim_date`, required by MetricFlow. |

| Semantic model | Built on | Time dimension | Counts |
|---|---|---|---|
| `transfers` | `fct_transfers` | `payment_created_at` | Successful payments with a receipt. Money measures use `if(is_successful_payment, ...)`, the same rule as `mart_finance_daily`. |
| `payments` | `fct_payments` | `created_at` | Every payment, any status. Source of conversion and risk. |
| `disbursements` | `fct_disbursements` | `created_at` | Payout attempts, not payments. |
| `users` | `dim_user` | `first_successful_payment_date` | Senders, by the date of their first successful payment. |

Joins: `user`, `corridor`, `payment_method`, `payment_status` and `payout_provider` entities link the facts to the dimension semantic models.

## 3. Metric catalog

"Mart equivalent" is the mart column that holds the same KPI for a fixed grain, when one exists.

### Revenue and volume (`transfers`)

| Metric | Definition | Mart equivalent |
|---|---|---|
| `tpv_usd` | Amount of successful payments in USD | `mart_finance_daily.tpv_usd` |
| `transfers_count` | Successful transfers | `mart_finance_daily.transfers_count` |
| `principal_usd` | Amount charged without fee | `mart_finance_daily.principal_usd` |
| `fee_revenue_usd` | Fees paid | `mart_finance_daily.fee_revenue_usd` |
| `promotion_cost_usd` | Promotions given to the beneficiary | `mart_finance_daily.promotion_cost_usd` |
| `net_revenue_usd` | Fee revenue minus promotion cost | `mart_finance_daily.net_revenue_usd` |
| `take_rate` | Fee revenue / TPV | `mart_finance_daily.take_rate` |
| `net_take_rate` | Net revenue / TPV | none |
| `promotion_intensity` | Promotion cost / fee revenue | none |
| `avg_ticket_usd` | TPV / transfers | `mart_finance_daily.avg_ticket_usd` |
| `active_senders` | Distinct users with a successful payment (not additive) | `mart_finance_daily.active_senders` |
| `net_revenue_per_sender_usd` | Net revenue / active senders | none |
| `transfer_retry_rate` | Successful transfers with more than one payout attempt / transfers | none |
| `retried_transfers` | Count behind the retry rate | `mart_user_daily.retried_count` |
| `transfers_per_sender` | Transfers / active senders | none |

### Payments and conversion (`payments`)

| Metric | Definition | Mart equivalent |
|---|---|---|
| `payments_count` | Payments attempted, any status | `mart_payment_conversion.payments_count` |
| `successful_payments`, `failed_payments`, `refunded_payments` | Payments by status | `mart_payment_conversion.*_count` |
| `attempted_amount_usd`, `successful_amount_usd` | Amount attempted and amount of successful payments | `mart_payment_conversion` |
| `failed_amount_usd` | Attempted minus successful amount | none |
| `success_rate` | Successful / attempted | `mart_payment_conversion.success_rate` |
| `refund_rate` | Refunded / (successful + refunded) | `mart_payment_conversion.refund_rate` |
| `recoverable_failed_payments` | Failures a retry or another method can fix: insufficient funds, authentication, provider or bank | none |
| `recoverable_failure_share` | Recoverable failures / all failures | none |

### Payouts and delivery (`disbursements`, plus `transfers` for end to end time)

| Metric | Definition | Mart equivalent |
|---|---|---|
| `payout_attempts` | Disbursement attempts | `mart_payout_performance.attempts_count` |
| `completed_attempts`, `failed_attempts`, `stuck_attempts`, `retry_attempts` | Attempts by outcome (stuck = in progress or on hold; retry = attempt number above 1) | `mart_payout_performance.*_count` |
| `completion_rate` | Completed / attempts | `mart_payout_performance.completion_rate` |
| `payout_failure_rate` | Failed / attempts | none |
| `stuck_rate` | Stuck / attempts | none |
| `retry_rate` | Retry attempts / attempts | `mart_payout_performance.retry_rate` |
| `avg_minutes_to_complete` | Average minutes, completed attempts with a valid duration | `mart_payout_performance.avg_minutes_to_complete` |
| `median_minutes_to_complete` | Approximate median minutes, completed attempts | `mart_payout_performance.median_minutes_to_complete` |
| `avg_minutes_payment_to_payout` | Average minutes from payment to completed payout | none |

Helper metrics (`minutes_completed_sum`, `minutes_completed_count`, `minutes_to_complete_sum`, `completed_payout_transfers`) are the numerators and denominators of the averages; query the averages instead.

### Customers (`users`, `transfers`)

| Metric | Definition | Mart equivalent |
|---|---|---|
| `new_senders` | Users whose first successful payment falls in the period | `mart_user_cohorts.cohort_users` (by month) |
| `repeat_senders` | Users with two or more successful payments, by date of their first one | none |
| `repeat_rate` | Repeat senders / new senders | none |
| `returning_senders` | Active senders minus new senders in the same period | none |

### Risk (`payments`)

| Metric | Definition | Mart equivalent |
|---|---|---|
| `disputed_payments` | Payments with a dispute or chargeback (merged in the source) | `mart_risk.disputed_count` |
| `disputed_amount_usd` | Amount of those payments | `mart_risk.disputed_amount_usd` |
| `dispute_rate` | Disputed / successful payments | `mart_risk.dispute_rate` |
| `disputed_share_of_tpv` | Disputed amount / successful amount | none |
| `fraud_failed_payments` | Payments failed with category `FRAUD_RISK` | `mart_risk.fraud_failed_count` |
| `fraud_failure_rate` | Fraud failures / payments attempted | `mart_risk.fraud_failure_rate` |

## Dimensions by metric family

A metric can only be grouped by the dimensions reachable from its semantic model. `metric_time` (day, week, month, quarter, year) is available everywhere.

| Metric family | Dimensions |
|---|---|
| Revenue, volume and transfers (`transfers`) | `corridor__corridor_name`, `corridor__country_code`, `corridor__country_name`, `corridor__subregion`, `corridor__currency_code`; `payment_method__method`, `payment_method__payment_method_category`; `transfer__is_retried`, `transfer__has_dispute_chargeback`; `user__*` |
| Payments and risk (`payments`) | `payment_method__method`, `payment_method__payment_method_category`; `payment_status__status`, `payment_status__payment_status_detail`, `payment_status__failure_category`; `payment__is_payout_not_created`; `user__*`. **No corridor.** |
| Payouts (`disbursements`) | `corridor__*`; `payout_provider__provider`, `payout_provider__payer_name`, `payout_provider__disbursement_method`; `disbursement__disbursement_status_group`; `user__*`. **No payment method.** |
| Customers (`users`) | `user__cohort_month__month`, `user__is_repeat_user`, `user__has_successful_payment`. `metric_time` is the date of the first successful payment. |

`user__*` means `user__cohort_month__month`, `user__first_successful_payment_date__day`, `user__has_successful_payment` and `user__is_repeat_user`. Time dimensions take a granularity suffix (`__day`, `__month`, ...). The semantic layer has no `user_id` dimension, so per-user rankings stay in `mart_user_daily`.

## 5. How to query it

`dbt sl` needs a dbt Cloud project, so the layer is validated and queried locally with the open-source MetricFlow CLI (`mf`). Setup commands are in the [root README](../README.md#semantic-layer).

```bash
cd DBT
export DBT_PROFILES_DIR=~/.dbt
dbt parse --no-partial-parse     # refresh the semantic manifest after any YAML change
mf validate-configs              # checks the layer against BigQuery
mf list metrics
mf list dimensions --metrics take_rate
mf query --metrics tpv_usd,take_rate --group-by metric_time__month,corridor__country_name --order metric_time__month
```

Other consumers (Looker, Google Sheets, BI tools, JDBC and GraphQL API) need the layer published through dbt Cloud. That step is not done; the architecture diagram marks them as dashed.

## Example queries by question

The question numbers refer to Part 2 of [business-questions-and-kpis.md](business-questions-and-kpis.md).

| Question | Query |
|---|---|
| 2.1 How much money do we move each month, and at what take rate? | `--metrics tpv_usd,take_rate --group-by metric_time__month` |
| 2.1 Which corridors generate the most TPV and net revenue? | `--metrics tpv_usd,net_revenue_usd,take_rate --group-by corridor__country_name --order -tpv_usd` |
| 2.1 Do promotions eat the margin in some regions? | `--metrics promotion_intensity,net_take_rate --group-by corridor__subregion` |
| 2.2 Which payment method converts best? | `--metrics success_rate,refund_rate --group-by payment_method__method` |
| 2.2 Why do payments fail? | `--metrics failed_payments --group-by payment_status__failure_category` |
| 2.2 How much money do we lose to failed payments, and how much is recoverable? | `--metrics failed_amount_usd,recoverable_failure_share --group-by payment_method__method` |
| 2.3 Which providers fail or are slow? | `--metrics completion_rate,payout_failure_rate,median_minutes_to_complete --group-by payout_provider__provider` |
| 2.3 Which payer institutions fail the most? | `--metrics payout_failure_rate,payout_attempts --group-by payout_provider__payer_name` |
| 2.3 How long from payment to money delivered, by corridor? | `--metrics avg_minutes_payment_to_payout --group-by corridor__country_name` |
| 2.4 New, active and returning senders per month | `--metrics new_senders,active_senders,returning_senders --group-by metric_time__month` |
| 2.4 What share of senders repeat, by acquisition month? | `--metrics repeat_rate --group-by user__cohort_month__month` |
| 2.5 Dispute and fraud rates by method | `--metrics dispute_rate,fraud_failure_rate --group-by payment_method__method` |
| 2.5 Do certain cohorts dispute more? | `--metrics dispute_rate --group-by user__cohort_month__month` |

Checked against BigQuery: monthly TPV adds up to the 237.69M USD of the reference figures, and the take rate is 1.22%. Run end to end: TPV and take rate by month, TPV, net revenue and take rate by country, success and refund rates by payment method, dispute and fraud rates by payment method, provider completion, failure and median time, payout failure by payer, payment to payout time by country, promotion intensity by subregion, repeat rate by cohort and the monthly sender metrics. Every metric passes `mf validate-configs`. The other combinations are valid by the dimension table but were not run one by one.

## 7. Limits and what is not in the layer

| Not in the layer | Why | Where it lives |
|---|---|---|
| Cumulative TPV, month-over-month growth, previous-period offsets | MetricFlow generates SQL that mixes `DATETIME` and `TIMESTAMP` and BigQuery rejects it | Compute in the BI layer; the mart `mart_finance_daily` has the daily series |
| Cohort retention | Needs the activity month relative to the cohort | `mart_user_cohorts` |
| Per-user detail (ranking, Pareto, time to second payment, churn) | No `user_id` dimension | `mart_user_daily`, `dim_user` |
| Data quality checks | Monitor tables, not business metrics | `mart_data_quality` |
| Fraud or failure rates by corridor | `payments` has no corridor entity | Proposed, see [business-questions-and-kpis.md](business-questions-and-kpis.md) |
| Chargeback rate separate from disputes | The source merges both | Not available |
| P90 and P95 delivery time, SLA compliance | Not defined yet | Proposed |

Other things to know:
- The project is named `felix_de_test` (no hyphens) because MetricFlow rejects hyphens in the project name.
- The legacy YAML spec is used; dbt 2.0 warns that it is deprecated. Migrating (with `dbt-autofix`) is in the pending work of [project-progress.md](project-progress.md#6-pending-work).
- `median_minutes_to_complete` is an approximate percentile, the only kind BigQuery supports in MetricFlow.
- `active_senders` is a distinct count and is not additive across groups.
