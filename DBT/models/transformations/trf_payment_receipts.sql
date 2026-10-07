-- One row per receipt (payout attempt) enriched with its payment and disbursement.
-- Disbursement is a left join: 185 receipts point to a disbursement that does not exist in the source.
with
receipts as (
    select * from {{ ref('stg_remittances__receipts') }}
),

disbursements as (
    select * from {{ ref('stg_remittances__disbursements') }}
),

attempts as (
    select
        receipts.*,
        row_number() over (
            partition by receipts.payment_id
            order by receipts.created_at, receipts.receipt_id
        )                                                   as attempt_number,
        count(*) over (partition by receipts.payment_id)    as attempts_count
    from receipts
),

final as (
    select
        attempts.receipt_id,
        attempts.payment_id,
        attempts.disbursement_id,
        attempts.user_id,
        attempts.beneficiary_id,
        attempts.attempt_number,
        attempts.attempts_count,
        attempts.attempt_number = attempts.attempts_count   as is_last_attempt,
        attempts.destination_country_code,
        attempts.destination_currency,
        attempts.amount_charged_usd,
        attempts.fee_usd,
        attempts.exchange_rate,
        attempts.promotion_amount_usd,
        attempts.destination_amount_local,
        attempts.created_at                                 as receipt_created_at,
        disbursements.disbursement_id is not null           as has_disbursement,
        disbursements.disbursement_method,
        disbursements.status                                as disbursement_status,
        disbursements.status_group                          as disbursement_status_group,
        disbursements.provider,
        disbursements.payer_name,
        disbursements.amount_local                          as disbursement_amount_local,
        disbursements.created_at                            as disbursement_created_at,
        disbursements.updated_at                            as disbursement_updated_at
    from attempts
    left join disbursements
        on attempts.disbursement_id = disbursements.disbursement_id
)

select * from final
