-- One row per sender (user_id) with lifetime activity. Base for dim_user and the cohort mart.
with
payments as (
    select * from {{ ref('stg_remittances__payments') }}
),

final as (
    select
        user_id,
        min(created_at)                                                 as first_payment_at,
        min(if(status = 'SUCCESSFUL', created_at, null))                as first_successful_payment_at,
        max(if(status = 'SUCCESSFUL', created_at, null))                as last_successful_payment_at,
        count(*)                                                        as payments_count,
        countif(status = 'SUCCESSFUL')                                  as successful_payments_count,
        sum(if(status = 'SUCCESSFUL', amount_usd, 0))                   as lifetime_tpv_usd
    from payments
    group by user_id
)

select * from final
