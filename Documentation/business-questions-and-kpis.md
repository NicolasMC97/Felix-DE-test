# Business KPIs and questions answered by the marts and the semantic layer

This document lists the KPIs available in the marts and in the semantic layer, and the business questions they answer, grouped by domain. Part 1 covers the KPIs, Part 2 the questions. How the semantic layer is built and queried: [semantic-layer.md](semantic-layer.md).

**KPI status**
- **Built**: exposed as a column in a mart today.
- **Derived**: computed from built columns (a ratio or a sum in the BI layer or in a query), no model change.
- **Semantic**: not a mart column, but available today as a metric in the semantic layer.
- **Proposed**: needs a new column or model. The dependency is stated.

The last column of every KPI table, **Semantic metric**, gives the metric name in the semantic layer (`DBT/models/semantic/`), or `-` when the KPI is not defined there. A KPI can be both a mart column and a metric: the mart is a precomputed table for a fixed grain, the metric is recomputed from the facts at any grain (country, method, provider, month). Metrics can only be grouped by dimensions reachable from their semantic model (see [semantic-layer.md](semantic-layer.md#dimensions-by-metric-family)).

**Marts**

| Mart | Grain |
|---|---|
| `mart_finance_daily` | day x corridor x payment method (successful payments only) |
| `mart_payment_conversion` | day x payment method |
| `mart_payout_performance` | day x provider x corridor (one row counts payout attempts) |
| `mart_user_cohorts` | cohort month x activity month |
| `mart_user_daily` | user x day (successful payments only) |
| `mart_risk` | month x payment method |
| `mart_data_quality` | month x check x issue type |

Notes that apply to every KPI:
- Ratios are not additive. When aggregating, sum the numerator and denominator and divide again.
- `active_senders` (finance) is not additive across groups. Use `mart_user_daily` to count distinct users over any period.
- All dates are UTC.

---

# Part 1. KPIs by domain

## 1.1 Revenue and volume

| KPI | Definition | Source | Status | Semantic metric |
|---|---|---|---|---|
| TPV (total payment volume) | Sum of successful payment amounts in USD | `mart_finance_daily.tpv_usd` | Built | `tpv_usd` |
| Transfers count | Successful transfers | `mart_finance_daily.transfers_count` | Built | `transfers_count` |
| Principal | Amount charged without fee | `mart_finance_daily.principal_usd` | Built | `principal_usd` |
| Fee revenue | Fees paid by senders | `mart_finance_daily.fee_revenue_usd` | Built | `fee_revenue_usd` |
| Promotion cost | Promotions given to the beneficiary | `mart_finance_daily.promotion_cost_usd` | Built | `promotion_cost_usd` |
| Net revenue | Fee revenue minus promotion cost | `mart_finance_daily.net_revenue_usd` | Built | `net_revenue_usd` |
| Take rate | Fee revenue / TPV | `mart_finance_daily.take_rate` | Built | `take_rate` |
| Average ticket | TPV / transfers | `mart_finance_daily.avg_ticket_usd` | Built | `avg_ticket_usd` |
| Promotion intensity | Promotion cost / fee revenue | `mart_finance_daily` | Derived | `promotion_intensity` |
| Net take rate | Net revenue / TPV | `mart_finance_daily` | Derived | `net_take_rate` |
| TPV growth (MoM, WoW, YoY) | Change of TPV against the previous period | `mart_finance_daily`, summed by period | Derived | - (left to the BI layer) |
| Share of TPV by corridor / method | Group TPV / total TPV | `mart_finance_daily` | Derived | - (BI layer, share of the total) |
| Revenue concentration (top N corridors) | Share of net revenue in the top N corridors | `mart_finance_daily` | Derived | - |
| Revenue per active sender | Net revenue / distinct senders in the period | `mart_user_daily` | Derived | `net_revenue_per_sender_usd` |
| Fee by corridor vs. cost to serve | Net revenue minus payout cost | Needs payout cost per provider (not in the source) | Proposed | - |

## 1.2 Payments and conversion

| KPI | Definition | Source | Status | Semantic metric |
|---|---|---|---|---|
| Payments attempted | All payments created | `mart_payment_conversion.payments_count` | Built | `payments_count` |
| Success rate | Successful / payments | `mart_payment_conversion.success_rate` | Built | `success_rate` |
| Refund rate | Refunded / (successful + refunded) | `mart_payment_conversion.refund_rate` | Built | `refund_rate` |
| Attempted vs. successful amount | Amount lost to failures | `attempted_amount_usd`, `successful_amount_usd` | Built | `attempted_amount_usd`, `successful_amount_usd` |
| Failures by category | Insufficient funds, fraud risk, authentication, invalid card, provider or bank, invalid request, other | `failed_*_count` | Built | `failed_payments` by `payment_status__failure_category` |
| Failure mix | Each category / total failures | `mart_payment_conversion` | Derived | `failed_payments` by `payment_status__failure_category` |
| Failed amount | `attempted_amount_usd` minus `successful_amount_usd` | `mart_payment_conversion` | Derived | `failed_amount_usd` |
| Recoverable failure share | Failures that a retry or a different method can fix (insufficient funds, authentication, provider or bank) / all failures | `mart_payment_conversion` | Derived | `recoverable_failure_share` |
| Retry rate of payments | Transfers with more than one payout attempt / transfers | `mart_user_daily.retried_count`, `mart_finance_daily.transfers_count` | Derived | `transfer_retry_rate` |
| Success rate by country | Success rate by sender country | Needs sender country or request attributes in the mart | Proposed | - |
| Conversion funnel (created, authorized, receipt, payout completed) | Share of payments reaching each milestone | `fct_transfers` milestone dates | Proposed | - |

## 1.3 Payouts and delivery

| KPI | Definition | Source | Status | Semantic metric |
|---|---|---|---|---|
| Payout attempts | Disbursement attempts | `mart_payout_performance.attempts_count` | Built | `payout_attempts` |
| Completion rate | Completed attempts / attempts | `mart_payout_performance.completion_rate` | Built | `completion_rate` |
| Status split | Completed, failed, cancelled, in progress, on hold | `*_count` columns | Built | `payout_attempts` by `disbursement__disbursement_status_group` |
| Retry rate | Attempts with `attempt_number > 1` / attempts | `mart_payout_performance.retry_rate` | Built | `retry_rate` |
| Average time to complete | Minutes, completed attempts only | `avg_minutes_to_complete` | Built | `avg_minutes_to_complete` |
| Median time to complete | Minutes, completed attempts only | `median_minutes_to_complete` | Built | `median_minutes_to_complete` |
| Failure rate | Failed / attempts | `mart_payout_performance` | Derived | `payout_failure_rate` |
| Stuck rate | (In progress + on hold) / attempts | `mart_payout_performance` | Derived | `stuck_rate` |
| Failed attempts by provider | Ranking of providers by `failed_count` | `mart_payout_performance` | Derived | `failed_attempts` by `payout_provider__provider` |
| Provider share of volume | Provider attempts / total attempts | `mart_payout_performance` | Derived | `payout_attempts` by `payout_provider__provider` |
| P90 / P95 time to complete | Tail of the delivery time | Add percentiles to the mart | Proposed | - |
| SLA compliance | Share of completed payouts under a target time (for example 30 minutes) | Add a threshold column | Proposed | - |
| Payout failure by payer institution | Failure rate per `payer_name` | Add payer to the mart grain | Semantic | `payout_failure_rate` by `payout_provider__payer_name` |
| Time from payment to completed payout | End to end delivery time | `fct_transfers.minutes_to_complete`, add to a mart | Semantic | `avg_minutes_payment_to_payout` |

## 1.4 Customers and growth

| KPI | Definition | Source | Status | Semantic metric |
|---|---|---|---|---|
| Cohort size | Users whose first successful payment is in the cohort month | `mart_user_cohorts.cohort_users` | Built | `new_senders` by `metric_time__month` |
| Active users | Cohort users with a successful payment in the month | `mart_user_cohorts.active_users` | Built | - |
| Retention rate | Active users / cohort users, by months since cohort | `mart_user_cohorts.retention_rate` | Built | - |
| TPV per cohort user | Cohort TPV in the month / cohort users | `mart_user_cohorts.tpv_per_cohort_user_usd` | Built | - |
| User daily activity | Transfers, TPV, fees, methods and corridors per user and day | `mart_user_daily` | Built | - |
| Days since first payment | Age of the user on each activity day | `mart_user_daily.days_since_first_payment` | Built | - |
| First payment day flag | New user marker | `mart_user_daily.is_first_payment_day` | Built | - |
| New senders per day / month | Count of rows with `is_first_payment_day` | `mart_user_daily` | Derived | `new_senders` |
| Daily / weekly / monthly active senders | Distinct `user_id` per period | `mart_user_daily` | Derived | `active_senders` |
| Returning senders | Active senders minus new senders | `mart_user_daily` | Derived | `returning_senders` |
| New vs. returning TPV | TPV split by `is_first_payment_day` | `mart_user_daily` | Derived | - |
| Repeat rate | Users with 2 or more successful payments / users (`dim_user.is_repeat_user`) | `dim_user` | Derived | `repeat_rate` |
| Time to second payment | Days between first and second successful payment | `mart_user_daily`, first two active days per user | Derived | - |
| Purchase frequency | Active days per user per month | `mart_user_daily` | Derived | - |
| Average ticket per user | TPV / transfers per user | `mart_user_daily.avg_ticket_usd` | Built | - |
| Multi-corridor and multi-method users | Users with `corridors_used` or `payment_methods_used` above 1 | `mart_user_daily` | Derived | - |
| Lifetime TPV per user | `dim_user.lifetime_tpv_usd` | `dim_user` | Built (dimension) | - |
| Pareto: users that make up 50% of TPV | Smallest set of users reaching half of the volume | `mart_user_daily` or `dim_user` | Proposed (listed in pending work) | - |
| Customer lifetime value | Cumulative net revenue per cohort user | Add net revenue to `mart_user_cohorts` | Proposed | - |
| Churn and reactivation | Users inactive for N days who come back | `mart_user_daily`, window over active days | Proposed | - |
| Beneficiary clusters | Groups of beneficiaries per user | Not feasible today: each beneficiary belongs to a single user | Not available | - |

## 1.5 Risk

| KPI | Definition | Source | Status | Semantic metric |
|---|---|---|---|---|
| Dispute rate | Disputed or charged back / successful payments | `mart_risk.dispute_rate` | Built | `dispute_rate` |
| Disputed amount | Amount in USD of disputed payments | `mart_risk.disputed_amount_usd` | Built | `disputed_amount_usd` |
| Refund rate | Refunded / (successful + refunded) | `mart_risk.refund_rate` | Built | `refund_rate` |
| Fraud failure rate | Failures with category `FRAUD_RISK` / payments attempted | `mart_risk.fraud_failure_rate` | Built | `fraud_failure_rate` |
| Disputed share of TPV | Disputed amount / successful amount | `mart_risk`, `mart_finance_daily` | Derived | `disputed_share_of_tpv` |
| Disputes per user | `disputed_count` per user | `mart_user_daily` | Derived | - |
| Dispute rate by cohort | Disputes by acquisition month | `mart_user_daily.cohort_month` | Derived | `dispute_rate` by `user__cohort_month__month` |
| Chargeback rate (separate from disputes) | Disputes and chargebacks are merged in the source, so today it is an approximation | Needs the source to split them | Not available | - |
| Fraud by corridor | Fraud failure rate per corridor | Add corridor to the risk grain | Proposed | - |
| Loss exposure | Disputed amount plus promotions given on disputed payments | Add promotion to `mart_risk` | Proposed | - |

## 1.6 Data quality and reliability

| KPI | Definition | Source | Status | Semantic metric |
|---|---|---|---|---|
| Affected records and percentage | Records with the issue / records in the population | `mart_data_quality.affected_records`, `affected_pct` | Built | - |
| Net and absolute amount involved | Money at stake for each check | `net_diff_usd`, `abs_diff_usd` | Built | - |
| Amount mismatch rate | Payments where amount differs from charged plus fee (0.13% today) | `check_name = 'AMOUNT_MISMATCH'` | Built | - |
| Receipts without disbursement | Receipts pointing to a missing disbursement | `check_name = 'RECEIPT_WITHOUT_DISBURSEMENT'` | Built | - |
| Successful payments without receipt | Payments with no payout created | `check_name = 'SUCCESSFUL_PAYMENT_WITHOUT_RECEIPT'` | Built | - |
| Failed payments with receipt | Receipts attached to failed payments | `check_name = 'FAILED_PAYMENT_WITH_RECEIPT'` | Built | - |
| Invalid disbursement timestamps | Null `updated_at` or earlier than `created_at` | `check_name = 'DISBURSEMENT_TIMESTAMPS'` | Built | - |
| Unreconciled amount trend | Month over month change of `abs_diff_usd` | `mart_data_quality` | Derived | - |
| Data freshness | Latest `created_at` against the current date | Add a freshness check | Proposed | - |

---

# Part 2. Business questions by domain

Each question lists the mart that answers it. Questions about metrics defined in the semantic layer can also be answered there with a group-by on the dimension named in the **How** column (for example `payment_method__method`, `corridor__country_name`, `payout_provider__provider`, `metric_time__month`). [semantic-layer.md](semantic-layer.md#example-queries-by-question) maps the main questions to ready-to-run queries.

## 2.1 Revenue and volume

| Question | Mart | How |
|---|---|---|
| How much money do we move each month? | `mart_finance_daily` | Sum `tpv_usd` by month |
| What is the monthly growth of TPV and of transfers? | `mart_finance_daily` | Compare each month with the previous one |
| What is our revenue and how much of it do promotions consume? | `mart_finance_daily` | `fee_revenue_usd`, `promotion_cost_usd`, `net_revenue_usd` |
| Which corridors generate the most TPV and the most net revenue? | `mart_finance_daily` | Group by `corridor_name` |
| Are we charging the same take rate in every corridor? Where is it lowest? | `mart_finance_daily` | `take_rate` by corridor |
| Which payment methods carry the highest take rate and average ticket? | `mart_finance_daily` | `take_rate`, `avg_ticket_usd` by method |
| Is there a weekly or monthly seasonality in volume? | `mart_finance_daily` | Daily series by weekday and month |
| How concentrated is our revenue in a few corridors? | `mart_finance_daily` | Share of net revenue in top N corridors |
| Do promotions pay off in some corridors and destroy margin in others? | `mart_finance_daily` | Promotion intensity and net take rate by corridor |
| Does the average ticket change by country or by method? | `mart_finance_daily` | `avg_ticket_usd` |
| How much revenue does each active sender bring? | `mart_user_daily` | Net revenue / distinct senders in the period |

## 2.2 Payments and conversion

| Question | Mart | How |
|---|---|---|
| What share of payment attempts succeed? | `mart_payment_conversion` | `success_rate` |
| Which payment method converts best and which worst? | `mart_payment_conversion` | `success_rate` by `payment_method` |
| Why do payments fail? | `mart_payment_conversion` | `failed_*_count` split |
| How much money do we lose to failed payments? | `mart_payment_conversion` | `attempted_amount_usd` minus `successful_amount_usd` |
| Is a failure type growing over time (for example authentication or provider or bank)? | `mart_payment_conversion` | Daily or monthly trend of each category |
| Which failures are recoverable with a retry or another method? | `mart_payment_conversion` | Insufficient funds, authentication, provider or bank |
| What share of payments are refunded, by method? | `mart_payment_conversion` | `refund_rate` |
| Did a conversion drop happen on a given day? | `mart_payment_conversion` | Daily `success_rate` |
| Which method category (card, cash, bank) is more reliable? | `mart_payment_conversion` | Group by `payment_method_category` |
| Which payments need more than one payout attempt? | `mart_user_daily` | `retried_count` |

## 2.3 Payouts and delivery

| Question | Mart | How |
|---|---|---|
| What share of payouts complete? | `mart_payout_performance` | `completion_rate` |
| Which providers have the most failed disbursements? | `mart_payout_performance` | Rank by `failed_count` and failure rate |
| Which provider is the fastest and which the slowest? | `mart_payout_performance` | `avg_minutes_to_complete`, `median_minutes_to_complete` |
| Which corridors have the worst delivery performance? | `mart_payout_performance` | Completion rate and median time by corridor |
| How often do payouts need a retry, and with which providers? | `mart_payout_performance` | `retry_rate` by provider |
| How many payouts are stuck in progress or on hold? | `mart_payout_performance` | `in_progress_count`, `on_hold_count` |
| Did a provider degrade on a specific day? | `mart_payout_performance` | Daily `completion_rate` by provider |
| Which provider should we route more or less volume to? | `mart_payout_performance` | Compare completion, retry rate and time per corridor |
| What share of payouts are cancelled, and is it linked to refunds? | `mart_payout_performance`, `mart_payment_conversion` | `cancelled_count` against `refund_rate` |
| What is the tail delivery time (P90, P95)? | Proposed | Needs percentiles in the mart |
| Are we meeting a delivery SLA? | Proposed | Needs an SLA threshold column |

## 2.4 Customers and growth

| Question | Mart | How |
|---|---|---|
| How many new senders do we acquire per month? | `mart_user_cohorts` | `cohort_users` |
| How many senders are active per day, week and month? | `mart_user_daily` | Distinct `user_id` by period |
| What is the retention of each cohort after 1, 3 and 6 months? | `mart_user_cohorts` | `retention_rate` by `months_since_cohort` |
| Which cohorts retain better and which worse? | `mart_user_cohorts` | Compare retention curves |
| How much does a cohort user spend over time? | `mart_user_cohorts` | `tpv_per_cohort_user_usd` |
| What share of customers are recurring? | `dim_user` | `is_repeat_user` |
| How long does it take a user to make a second payment? | `mart_user_daily` | Days between first and second active day |
| How is the volume split between new and returning senders? | `mart_user_daily` | TPV by `is_first_payment_day` |
| How often does a user send money in a month? | `mart_user_daily` | Active days per user and month |
| Which users are the most valuable? | `mart_user_daily`, `dim_user` | `lifetime_tpv_usd`, fees paid |
| Do users use more than one method or corridor? | `mart_user_daily` | `payment_methods_used`, `corridors_used` |
| What does a user do on the first payment day vs. later days? | `mart_user_daily` | Compare by `days_since_first_payment` |
| Which users stopped sending and when? | `mart_user_daily` | Last active day per user against today |
| Which corridors attract new users? | `mart_user_daily` and `fct_transfers` | First payment by corridor (needs corridor in the user grain) |
| Which users make up 50% of the volume? | Proposed | Pareto over `lifetime_tpv_usd` (pending work) |
| What is the lifetime value of each cohort? | Proposed | Needs net revenue in `mart_user_cohorts` |

## 2.5 Risk

| Question | Mart | How |
|---|---|---|
| What is our dispute and chargeback rate? | `mart_risk` | `dispute_rate` (approximation, see note) |
| How much money is disputed? | `mart_risk` | `disputed_amount_usd` |
| Which payment methods carry more disputes and refunds? | `mart_risk` | `dispute_rate`, `refund_rate` by method |
| How many payments are blocked for fraud risk? | `mart_risk` | `fraud_failed_count`, `fraud_failure_rate` |
| Is risk getting better or worse over time? | `mart_risk` | Monthly trend of each rate |
| Are disputes concentrated in a few users? | `mart_user_daily` | `disputed_count` per user |
| Do certain cohorts dispute more? | `mart_user_daily` | Disputes by `cohort_month` |
| Do users dispute more on their first payment day? | `mart_user_daily` | `disputed_count` where `is_first_payment_day` |
| Is there a link between promotions and disputes? | `mart_user_daily` | `promotion_cost_usd` against `disputed_count` |
| Which corridors or providers concentrate fraud? | Proposed | Needs corridor in the risk grain |

Note: the source merges disputes and chargebacks in one field, so the chargeback rate is an approximation until the two are separated.

## 2.6 Data quality and reliability

| Question | Mart | How |
|---|---|---|
| Can we trust the amounts? How many payments do not match charged plus fee? | `mart_data_quality` | `AMOUNT_MISMATCH` rows |
| How much money is involved in the mismatches? | `mart_data_quality` | `net_diff_usd`, `abs_diff_usd` |
| Which type of mismatch is the most frequent? | `mart_data_quality` | `issue_type` for `AMOUNT_MISMATCH` |
| How many successful payments have no payout created? | `mart_data_quality` | `SUCCESSFUL_PAYMENT_WITHOUT_RECEIPT` |
| Are there receipts without a disbursement? | `mart_data_quality` | `RECEIPT_WITHOUT_DISBURSEMENT` |
| Are failed payments generating receipts? | `mart_data_quality` | `FAILED_PAYMENT_WITH_RECEIPT` |
| Are disbursement timestamps reliable for delivery metrics? | `mart_data_quality` | `DISBURSEMENT_TIMESTAMPS` |
| Is data quality improving month over month? | `mart_data_quality` | Trend of `affected_pct` |
| Which months need to be reviewed before closing the books? | `mart_data_quality` | Months with the highest `abs_diff_usd` |
| Is the data fresh? | Proposed | Needs a freshness check |

---

# Cross-domain questions

| Question | Marts |
|---|---|
| Does a provider with low completion rate also have more refunds and disputes? | `mart_payout_performance`, `mart_risk` |
| Do corridors with slow payouts show lower retention? | `mart_payout_performance`, `mart_user_cohorts` (needs corridor in cohort grain) |
| Is net revenue growth coming from more users or from higher volume per user? | `mart_finance_daily`, `mart_user_daily` |
| How much revenue is at risk from failed payments, disputes and mismatches together? | `mart_payment_conversion`, `mart_risk`, `mart_data_quality` |
| Which cohort-method-corridor combinations are the most profitable and the safest? | `mart_user_daily`, `mart_finance_daily`, `mart_risk` |
