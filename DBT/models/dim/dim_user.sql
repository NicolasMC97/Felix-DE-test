-- One row per sender. Attributes are derived from payment activity (the source has no user attributes).
with
activity as (
    select * from {{ ref('trf_user_activity') }}
),

final as (
    select
        user_id,
        date(first_payment_at)                              as first_payment_date,
        date(first_successful_payment_at)                   as first_successful_payment_date,
        date_trunc(date(first_successful_payment_at), month) as cohort_month,
        successful_payments_count > 0                       as has_successful_payment,
        successful_payments_count >= 2                      as is_repeat_user,
        payments_count,
        successful_payments_count,
        lifetime_tpv_usd
    from activity
)

select * from final
