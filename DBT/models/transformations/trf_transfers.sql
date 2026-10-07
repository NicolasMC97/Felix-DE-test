-- One row per payment that has at least one receipt (the transfer).
-- Money comes from the payment and from the LAST receipt only: summing receipts double counts,
-- because every retry repeats the full amount.
with
payments as (
    select * from {{ ref('stg_remittances__payments') }}
),

last_attempt as (
    select *
    from {{ ref('trf_payment_receipts') }}
    where is_last_attempt
),

joined as (
    select
        payments.payment_id,
        payments.user_id,
        payments.status                                     as payment_status,
        payments.status_detail                              as payment_status_detail,
        payments.payment_method,
        payments.has_dispute_chargeback,
        payments.created_at                                 as payment_created_at,
        payments.updated_at                                 as payment_updated_at,

        last_attempt.receipt_id,
        last_attempt.disbursement_id,
        last_attempt.beneficiary_id,
        last_attempt.attempts_count,
        last_attempt.destination_country_code,
        last_attempt.destination_currency,
        last_attempt.exchange_rate,
        last_attempt.destination_amount_local,
        last_attempt.receipt_created_at,

        last_attempt.has_disbursement,
        last_attempt.disbursement_method,
        last_attempt.disbursement_status                    as payout_status,
        last_attempt.disbursement_status_group              as payout_status_group,
        last_attempt.provider,
        last_attempt.payer_name,
        last_attempt.disbursement_updated_at,

        payments.amount_usd                                 as payment_amount_usd,
        last_attempt.amount_charged_usd,
        last_attempt.fee_usd,
        last_attempt.promotion_amount_usd,
        last_attempt.amount_charged_usd + last_attempt.fee_usd  as expected_amount_usd
    from payments
    inner join last_attempt
        on payments.payment_id = last_attempt.payment_id
),

final as (
    select
        *,
        round(payment_amount_usd - expected_amount_usd, 2)  as amount_diff_usd,

        if(payout_status_group = 'COMPLETED', disbursement_updated_at, null)
                                                            as payout_completed_at,
        if(
            payout_status_group = 'COMPLETED',
            timestamp_diff(disbursement_updated_at, payment_created_at, minute),
            null
        )                                                   as minutes_to_complete
    from joined
),

flagged as (
    select
        *,
        abs(amount_diff_usd) >= 0.01                        as has_amount_mismatch,
        -- Classification of the business rule payment amount = amount_charged + fee
        case
            when abs(amount_diff_usd) < 0.01 then null
            when payment_amount_usd <= 0 or amount_charged_usd < 0 then 'NEGATIVE_OR_ZERO_AMOUNT'
            when amount_diff_usd > 0 and fee_usd = 0 then 'FEE_NOT_RECORDED'
            when amount_diff_usd < 0 then 'RECEIPT_HIGHER'
            else 'OTHER'
        end                                                 as amount_mismatch_type
    from final
)

select * from flagged
