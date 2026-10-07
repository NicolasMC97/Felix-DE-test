-- Behavior per user per payment creation day. Only successful payments.
-- Days without a successful payment have no row. Cohort comes from dim_user (first successful payment).
with
transfers as (
    select * from {{ ref('fct_transfers') }}
    where is_successful_payment
),

dates as (
    select date_key, date_day from {{ ref('dim_date') }}
),

users as (
    select user_id, first_successful_payment_date, cohort_month from {{ ref('dim_user') }}
),

daily as (
    select
        transfers.user_id,
        dates.date_day,

        count(*)                                                        as transfers_count,
        count(distinct transfers.payment_method_key)                    as payment_methods_used,
        count(distinct transfers.corridor_key)                          as corridors_used,
        sum(transfers.payment_amount_usd)                               as tpv_usd,
        sum(transfers.fee_usd)                                          as fee_revenue_usd,
        sum(transfers.promotion_amount_usd)                             as promotion_cost_usd,
        safe_divide(sum(transfers.payment_amount_usd), count(*))        as avg_ticket_usd,
        countif(transfers.is_retried)                                   as retried_count,
        countif(transfers.has_dispute_chargeback)                       as disputed_count
    from transfers
    inner join dates on transfers.payment_created_date_key = dates.date_key
    group by 1, 2
),

final as (
    select
        daily.user_id,
        daily.date_day,
        users.cohort_month,
        date_diff(daily.date_day, users.first_successful_payment_date, day) as days_since_first_payment,
        daily.date_day = users.first_successful_payment_date                as is_first_payment_day,
        daily.transfers_count,
        daily.payment_methods_used,
        daily.corridors_used,
        daily.tpv_usd,
        daily.fee_revenue_usd,
        daily.promotion_cost_usd,
        daily.avg_ticket_usd,
        daily.retried_count,
        daily.disputed_count
    from daily
    inner join users on daily.user_id = users.user_id
)

select * from final
