-- One row per payment (charge to the sender), any status. Source of payment conversion and refund / dispute metrics.
with
payments as (
    select * from {{ ref('stg_remittances__payments') }}
),

transfers as (
    select payment_id, attempts_count
    from {{ ref('trf_transfers') }}
),

final as (
    select
        payments.payment_id,
        payments.user_id,
        {{ date_key('payments.created_at') }}                                       as payment_created_date_key,
        {{ generate_surrogate_key(["coalesce(payments.payment_method, 'UNKNOWN')"]) }} as payment_method_key,
        {{ generate_surrogate_key(['payments.status', "coalesce(payments.status_detail, 'NONE')"]) }} as payment_status_key,

        payments.amount_usd,
        payments.status                                                             as payment_status,
        payments.status = 'SUCCESSFUL'                                              as is_successful,
        payments.status = 'REFUNDED'                                                as is_refunded,
        payments.status = 'FAILED'                                                  as is_failed,
        coalesce(payments.has_dispute_chargeback, false)                            as has_dispute_chargeback,
        payments.request_state_code,
        payments.total_intents,

        transfers.payment_id is not null                                            as has_receipt,
        coalesce(transfers.attempts_count, 0)                                       as payout_attempts_count,
        -- Successful charge with no receipt: the payout was not created (yet)
        payments.status = 'SUCCESSFUL' and transfers.payment_id is null             as is_payout_not_created,

        payments.created_at,
        payments.updated_at
    from payments
    left join transfers
        on payments.payment_id = transfers.payment_id
)

select * from final
