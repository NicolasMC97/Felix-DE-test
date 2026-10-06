{{ config(severity='warn') }}

-- Payments should not have negative amounts (zero is tolerated but reviewed upstream).
select payment_id, amount_usd
from {{ ref('stg_remittances__payments') }}
where amount_usd < 0
