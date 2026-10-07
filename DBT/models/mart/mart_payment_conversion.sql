-- Payment conversion per creation day and payment method, with failures split by category.
with
payments as (
    select * from {{ ref('fct_payments') }}
),

statuses as (
    select payment_status_key, failure_category from {{ ref('dim_payment_status') }}
),

methods as (
    select payment_method_key, payment_method, payment_method_category from {{ ref('dim_payment_method') }}
),

dates as (
    select date_key, date_day from {{ ref('dim_date') }}
),

final as (
    select
        dates.date_day,
        methods.payment_method,
        methods.payment_method_category,

        count(*)                                                        as payments_count,
        countif(payments.is_successful)                                 as successful_count,
        countif(payments.is_failed)                                     as failed_count,
        countif(payments.is_refunded)                                   as refunded_count,
        safe_divide(countif(payments.is_successful), count(*))          as success_rate,
        safe_divide(countif(payments.is_refunded), count(*))            as refund_rate,
        sum(payments.amount_usd)                                        as attempted_amount_usd,
        sum(if(payments.is_successful, payments.amount_usd, 0))         as successful_amount_usd,

        countif(statuses.failure_category = 'INSUFFICIENT_FUNDS')       as failed_insufficient_funds_count,
        countif(statuses.failure_category = 'FRAUD_RISK')               as failed_fraud_risk_count,
        countif(statuses.failure_category = 'AUTHENTICATION')           as failed_authentication_count,
        countif(statuses.failure_category = 'INVALID_CARD')             as failed_invalid_card_count,
        countif(statuses.failure_category = 'PROVIDER_OR_BANK')         as failed_provider_or_bank_count,
        countif(statuses.failure_category = 'INVALID_REQUEST')          as failed_invalid_request_count,
        countif(statuses.failure_category in ('UNKNOWN_REASON', 'OTHER')) as failed_other_count
    from payments
    inner join statuses on payments.payment_status_key = statuses.payment_status_key
    inner join methods on payments.payment_method_key = methods.payment_method_key
    inner join dates on payments.payment_created_date_key = dates.date_key
    group by 1, 2, 3
)

select * from final
