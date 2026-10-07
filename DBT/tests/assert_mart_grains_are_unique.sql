-- The declared grain of each mart must hold: no duplicated key combination.
select 'mart_finance_daily' as model, count(*) as n
from {{ ref('mart_finance_daily') }}
group by date_day, corridor_name, payment_method
having count(*) > 1
union all
select 'mart_payment_conversion', count(*)
from {{ ref('mart_payment_conversion') }}
group by date_day, payment_method
having count(*) > 1
union all
select 'mart_payout_performance', count(*)
from {{ ref('mart_payout_performance') }}
group by date_day, provider, corridor_name
having count(*) > 1
union all
select 'mart_user_cohorts', count(*)
from {{ ref('mart_user_cohorts') }}
group by cohort_month, activity_month
having count(*) > 1
union all
select 'mart_risk', count(*)
from {{ ref('mart_risk') }}
group by payment_month, payment_method
having count(*) > 1
union all
select 'mart_data_quality', count(*)
from {{ ref('mart_data_quality') }}
group by month, check_name, issue_type
having count(*) > 1
union all
select 'mart_user_daily', count(*)
from {{ ref('mart_user_daily') }}
group by user_id, date_day
having count(*) > 1
