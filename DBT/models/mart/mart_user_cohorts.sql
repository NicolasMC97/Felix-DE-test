-- Monthly retention by acquisition cohort. Cohort = month of the user's first successful payment.
-- Active = user with at least one successful payment in the activity month.
with
payments as (
    select user_id, amount_usd, created_at
    from {{ ref('fct_payments') }}
    where is_successful
),

users as (
    select user_id, cohort_month
    from {{ ref('dim_user') }}
    where has_successful_payment
),

cohort_size as (
    select cohort_month, count(*) as cohort_users
    from users
    group by 1
),

activity as (
    select
        users.cohort_month,
        date_trunc(date(payments.created_at), month)    as activity_month,
        count(distinct payments.user_id)                as active_users,
        count(*)                                        as transfers_count,
        sum(payments.amount_usd)                        as tpv_usd
    from payments
    inner join users on payments.user_id = users.user_id
    group by 1, 2
),

final as (
    select
        activity.cohort_month,
        activity.activity_month,
        date_diff(activity.activity_month, activity.cohort_month, month) as months_since_cohort,
        cohort_size.cohort_users,
        activity.active_users,
        safe_divide(activity.active_users, cohort_size.cohort_users)     as retention_rate,
        activity.transfers_count,
        activity.tpv_usd,
        safe_divide(activity.tpv_usd, cohort_size.cohort_users)          as tpv_per_cohort_user_usd
    from activity
    inner join cohort_size on activity.cohort_month = cohort_size.cohort_month
)

select * from final
