-- Every rate exposed by the marts must be between 0 and 1.
select 'mart_finance_daily' as model, date_day as period from {{ ref('mart_finance_daily') }}
where take_rate < 0 or take_rate > 1
union all
select 'mart_payment_conversion', date_day from {{ ref('mart_payment_conversion') }}
where success_rate not between 0 and 1 or refund_rate not between 0 and 1
union all
select 'mart_payout_performance', date_day from {{ ref('mart_payout_performance') }}
where completion_rate not between 0 and 1 or retry_rate not between 0 and 1
union all
select 'mart_user_cohorts', activity_month from {{ ref('mart_user_cohorts') }}
where retention_rate not between 0 and 1
union all
select 'mart_risk', payment_month from {{ ref('mart_risk') }}
where dispute_rate not between 0 and 1 or refund_rate not between 0 and 1 or fraud_failure_rate not between 0 and 1
union all
select 'mart_data_quality', month from {{ ref('mart_data_quality') }}
where affected_pct not between 0 and 1
