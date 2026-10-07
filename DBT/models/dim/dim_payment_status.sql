-- One row per payment status + detailed status, with a failure category to analyse why payments fail.
with
statuses as (
    select distinct
        status                                  as payment_status,
        coalesce(status_detail, 'NONE')         as payment_status_detail
    from {{ ref('stg_remittances__payments') }}
),

final as (
    select
        {{ generate_surrogate_key(['payment_status', 'payment_status_detail']) }} as payment_status_key,
        payment_status,
        payment_status_detail,
        case
            when payment_status <> 'FAILED' then null
            when payment_status_detail in (
                'FAILED_DUE_TO_INSUFFICIENT_FUNDS',
                'FAILED_DUE_TO_EARLY_INSUFFICIENT_FUNDS_CHECK',
                'FAILED_DUE_TO_BALANCE_STALE',
                'FAILED_DUE_TO_BALANCE_NOT_PRESENT'
            ) then 'INSUFFICIENT_FUNDS'
            when payment_status_detail in (
                'FAILED_DUE_TO_SUSPECTED_FRAUD_BY_PROCESSOR',
                'FAILED_DUE_TO_STOLEN_CARD',
                'FAILED_DUE_TO_REPORTED_LOST'
            ) then 'FRAUD_RISK'
            when payment_status_detail in (
                'FAILED_DUE_TO_3DS_CHALLENGE_FAILED',
                'PENDING_USER_ACTION_3DS_CHALLENGE'
            ) then 'AUTHENTICATION'
            when payment_status_detail in (
                'FAILED_DUE_TO_CVV_ERROR',
                'FAILED_DUE_TO_EXPIRED_CARD',
                'FAILED_DUE_TO_CARD_INVALID'
            ) then 'INVALID_CARD'
            when payment_status_detail in (
                'FAILED_DUE_TO_BANK_REJECTION',
                'FAILED_DUE_TO_REJECTION_BY_PROVIDER',
                'FAILED_DUE_TO_PROVIDER_ERROR',
                'FAILED_DUE_TO_TERMINAL_ERROR',
                'FAILED_DUE_TO_EXTERNAL_CALL_FAILURE',
                'FAILED_TRANSACTION_EXPIRED_BY_PROVIDER'
            ) then 'PROVIDER_OR_BANK'
            when payment_status_detail in (
                'FAILED_DUE_TO_INVALID_AMOUNT',
                'FAILED_DUE_TO_INVALID_TRANSACTION',
                'FAILED_DUE_TO_INVALID_MERCHANT',
                'FAILED_DUE_TO_CASH_CODE_EXPIRE'
            ) then 'INVALID_REQUEST'
            when payment_status_detail = 'FAILED_DUE_TO_UNMAPPED_REASON' then 'UNKNOWN_REASON'
            else 'OTHER'
        end                                     as failure_category
    from statuses
)

select * from final
