-- One row per transfer: a payment that has at least one receipt (accumulating snapshot).
-- Milestone dates: payment created -> receipt created -> payout completed (null until completed).
-- Money is taken from the payment and the last receipt only. Source of TPV, fees, take rate and delivery time.
with
transfers as (
    select * from {{ ref('trf_transfers') }}
),

final as (
    select
        payment_id,
        receipt_id,
        disbursement_id,
        user_id,

        {{ date_key('payment_created_at') }}                                        as payment_created_date_key,
        {{ date_key('receipt_created_at') }}                                        as receipt_created_date_key,
        {{ date_key('payout_completed_at') }}                                       as payout_completed_date_key,

        {{ generate_surrogate_key(['destination_country_code', 'destination_currency']) }} as corridor_key,
        {{ generate_surrogate_key(["coalesce(payment_method, 'UNKNOWN')"]) }}       as payment_method_key,
        {{ generate_surrogate_key(['payment_status', "coalesce(payment_status_detail, 'NONE')"]) }} as payment_status_key,
        -- Null when the receipt points to a disbursement that does not exist in the source
        if(has_disbursement, {{ generate_surrogate_key([
            "coalesce(provider, 'UNKNOWN')",
            "coalesce(payer_name, 'UNKNOWN')",
            "coalesce(disbursement_method, 'UNKNOWN')"
        ]) }}, null)                                                                as payout_provider_key,
        if(has_disbursement, {{ generate_surrogate_key(["coalesce(payout_status, 'UNKNOWN')"]) }}, null)
                                                                                    as disbursement_status_key,

        payment_amount_usd,
        amount_charged_usd,
        fee_usd,
        promotion_amount_usd,
        exchange_rate,
        destination_amount_local,

        payment_status,
        payout_status_group,
        payment_status = 'SUCCESSFUL'                                               as is_successful_payment,
        payout_status_group = 'COMPLETED'                                           as is_payout_completed,
        has_disbursement,
        attempts_count,
        attempts_count > 1                                                          as is_retried,
        minutes_to_complete,
        has_dispute_chargeback,

        -- Reconciliation of payment amount = amount_charged + fee (kept for the data quality mart)
        expected_amount_usd,
        amount_diff_usd,
        has_amount_mismatch,
        amount_mismatch_type,

        payment_created_at,
        receipt_created_at,
        payout_completed_at
    from transfers
)

select * from final
