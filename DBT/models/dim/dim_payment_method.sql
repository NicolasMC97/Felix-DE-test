-- One row per payment method.
with
methods as (
    select distinct coalesce(payment_method, 'UNKNOWN') as payment_method
    from {{ ref('stg_remittances__payments') }}
),

final as (
    select
        {{ generate_surrogate_key(['payment_method']) }} as payment_method_key,
        payment_method,
        case payment_method
            when 'CARD' then 'CARD'
            when 'APPLE_PAY' then 'DIGITAL_WALLET'
            when 'WALLET_POC' then 'DIGITAL_WALLET'
            when 'CASH' then 'CASH'
            when 'ACH' then 'BANK_TRANSFER'
            else 'UNKNOWN'
        end                                              as payment_method_category,
        -- Only CASH and ACH report the US state of the request (rarely: see staging docs)
        payment_method in ('CASH', 'ACH')                as reports_request_state
    from methods
)

select * from final
