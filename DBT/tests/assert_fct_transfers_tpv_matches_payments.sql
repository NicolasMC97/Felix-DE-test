-- TPV in fct_transfers must equal the amount of the same payments in fct_payments (no duplication from receipt retries).
with
transfers as (
    select round(sum(payment_amount_usd), 2) as tpv_usd from {{ ref('fct_transfers') }}
),

payments as (
    select round(sum(p.amount_usd), 2) as tpv_usd
    from {{ ref('fct_payments') }} as p
    where p.has_receipt
)

select transfers.tpv_usd as transfers_tpv_usd, payments.tpv_usd as payments_tpv_usd
from transfers
cross join payments
where transfers.tpv_usd <> payments.tpv_usd
