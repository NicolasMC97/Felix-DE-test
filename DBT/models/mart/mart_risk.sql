-- Risk indicators per creation month and payment method: disputes / chargebacks, refunds and fraud-related failures.
-- Dispute rate is measured over successful payments, fraud failure rate over all payments attempted.
with
payments as (
    select * from {{ ref('fct_payments') }}
),

statuses as (
    select payment_status_key, failure_category from {{ ref('dim_payment_status') }}
),

methods as (
    select payment_method_key, payment_method from {{ ref('dim_payment_method') }}
),

final as (
    select
        date_trunc(date(payments.created_at), month)                        as payment_month,
        methods.payment_method,

        count(*)                                                            as payments_count,
        countif(payments.is_successful)                                     as successful_count,
        countif(payments.has_dispute_chargeback)                            as disputed_count,
        sum(if(payments.has_dispute_chargeback, payments.amount_usd, 0))    as disputed_amount_usd,
        safe_divide(countif(payments.has_dispute_chargeback), countif(payments.is_successful))
                                                                            as dispute_rate,
        countif(payments.is_refunded)                                       as refunded_count,
        safe_divide(countif(payments.is_refunded), countif(payments.is_successful or payments.is_refunded))
                                                                            as refund_rate,
        countif(statuses.failure_category = 'FRAUD_RISK')                   as fraud_failed_count,
        safe_divide(countif(statuses.failure_category = 'FRAUD_RISK'), count(*))
                                                                            as fraud_failure_rate
    from payments
    inner join statuses on payments.payment_status_key = statuses.payment_status_key
    inner join methods on payments.payment_method_key = methods.payment_method_key
    group by 1, 2
)

select * from final
