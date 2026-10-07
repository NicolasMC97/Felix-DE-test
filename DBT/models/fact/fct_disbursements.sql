-- One row per disbursement (payout attempt). Source of payout success, retry and delivery time metrics.
-- Corridor comes from the receipt because destination_country is incomplete in disbursements.
with
disbursements as (
    select * from {{ ref('stg_remittances__disbursements') }}
),

receipts as (
    select * from {{ ref('trf_payment_receipts') }}
),

final as (
    select
        disbursements.disbursement_id,
        receipts.receipt_id,
        receipts.payment_id,
        receipts.user_id,
        {{ date_key('disbursements.created_at') }}                                  as disbursement_created_date_key,
        {{ generate_surrogate_key(['receipts.destination_country_code', 'receipts.destination_currency']) }} as corridor_key,
        {{ generate_surrogate_key([
            "coalesce(disbursements.provider, 'UNKNOWN')",
            "coalesce(disbursements.payer_name, 'UNKNOWN')",
            "coalesce(disbursements.disbursement_method, 'UNKNOWN')"
        ]) }}                                                                       as payout_provider_key,
        {{ generate_surrogate_key(["coalesce(disbursements.status, 'UNKNOWN')"]) }} as disbursement_status_key,

        disbursements.amount_local,
        disbursements.status_group                                                  as disbursement_status_group,
        disbursements.status_group = 'COMPLETED'                                    as is_completed,
        receipts.attempt_number,
        receipts.attempts_count,
        receipts.is_last_attempt,
        -- Null when updated_at is missing or earlier than created_at (known data quality issues)
        if(
            disbursements.updated_at >= disbursements.created_at,
            timestamp_diff(disbursements.updated_at, disbursements.created_at, minute),
            null
        )                                                                           as minutes_since_creation,

        disbursements.created_at,
        disbursements.updated_at
    from disbursements
    inner join receipts
        on disbursements.disbursement_id = receipts.disbursement_id
)

select * from final
