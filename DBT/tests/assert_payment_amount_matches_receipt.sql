{{ config(severity='warn') }}

-- For payments with a single receipt, payment amount must equal amount_charged + fee (tolerance 0.01 USD).
-- Payments with retried payouts (several receipts) are excluded.
with single_receipt as (
    select
        payment_id,
        any_value(amount_charged_usd) as amount_charged_usd,
        any_value(fee_usd)            as fee_usd
    from {{ ref('stg_remittances__receipts') }}
    group by payment_id
    having count(*) = 1
)

select p.payment_id
from {{ ref('stg_remittances__payments') }} as p
inner join single_receipt as r using (payment_id)
where abs(p.amount_usd - (r.amount_charged_usd + r.fee_usd)) > 0.01
