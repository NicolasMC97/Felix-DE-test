-- Amounts in receipts must be consistent: positive principal, non-negative fee / promotion, positive rate.
select receipt_id
from {{ ref('stg_remittances__receipts') }}
where amount_charged_usd <= 0
   or fee_usd < 0
   or promotion_amount_usd < 0
   or exchange_rate <= 0
   or destination_amount_local <= 0
