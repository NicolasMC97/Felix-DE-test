{{ config(severity='warn') }}

-- Amounts in receipts must be consistent: non-negative charge, non-negative fee / promotion, positive rate and destination amount.
-- amount_charged_usd may be 0 only when a promotion covered the whole transfer.
select receipt_id
from {{ ref('stg_remittances__receipts') }}
where amount_charged_usd < 0
   or (amount_charged_usd = 0 and promotion_amount_usd <= 0)
   or fee_usd < 0
   or promotion_amount_usd < 0
   or exchange_rate <= 0
   or destination_amount_local <= 0
