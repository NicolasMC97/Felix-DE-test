-- Finance KPIs per payment creation day, corridor and payment method. Only successful payments.
-- Take rate = fee revenue / TPV. Net revenue = fees minus promotions given to the beneficiary.
with
transfers as (
    select * from {{ ref('fct_transfers') }}
    where is_successful_payment
),

dates as (
    select date_key, date_day from {{ ref('dim_date') }}
),

corridors as (
    select corridor_key, corridor_name, country_code, country_name, currency_code from {{ ref('dim_corridor') }}
),

methods as (
    select payment_method_key, payment_method, payment_method_category from {{ ref('dim_payment_method') }}
),

final as (
    select
        dates.date_day,
        corridors.corridor_name,
        corridors.country_code,
        corridors.country_name,
        corridors.currency_code,
        methods.payment_method,
        methods.payment_method_category,

        count(*)                                                    as transfers_count,
        count(distinct transfers.user_id)                           as active_senders,
        sum(transfers.payment_amount_usd)                           as tpv_usd,
        sum(transfers.amount_charged_usd)                           as principal_usd,
        sum(transfers.fee_usd)                                      as fee_revenue_usd,
        sum(transfers.promotion_amount_usd)                         as promotion_cost_usd,
        sum(transfers.fee_usd) - sum(transfers.promotion_amount_usd) as net_revenue_usd,
        safe_divide(sum(transfers.fee_usd), sum(transfers.payment_amount_usd)) as take_rate,
        safe_divide(sum(transfers.payment_amount_usd), count(*))    as avg_ticket_usd
    from transfers
    inner join dates on transfers.payment_created_date_key = dates.date_key
    inner join corridors on transfers.corridor_key = corridors.corridor_key
    inner join methods on transfers.payment_method_key = methods.payment_method_key
    group by 1, 2, 3, 4, 5, 6, 7
)

select * from final
