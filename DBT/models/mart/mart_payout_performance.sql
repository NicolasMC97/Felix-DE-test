-- Payout performance per disbursement creation day, provider and corridor. One row counts attempts, not payments.
-- Delivery time uses only completed attempts with a valid updated_at.
with
disbursements as (
    select * from {{ ref('fct_disbursements') }}
),

providers as (
    select distinct payout_provider_key, provider from {{ ref('dim_payout_provider') }}
),

corridors as (
    select corridor_key, corridor_name, country_code, country_name, currency_code from {{ ref('dim_corridor') }}
),

dates as (
    select date_key, date_day from {{ ref('dim_date') }}
),

final as (
    select
        dates.date_day,
        providers.provider,
        corridors.corridor_name,
        corridors.country_code,
        corridors.country_name,
        corridors.currency_code,

        count(*)                                                            as attempts_count,
        countif(disbursements.disbursement_status_group = 'COMPLETED')      as completed_count,
        countif(disbursements.disbursement_status_group = 'FAILED')         as failed_count,
        countif(disbursements.disbursement_status_group = 'CANCELLED')      as cancelled_count,
        countif(disbursements.disbursement_status_group = 'IN_PROGRESS')    as in_progress_count,
        countif(disbursements.disbursement_status_group = 'ON_HOLD')        as on_hold_count,
        safe_divide(countif(disbursements.is_completed), count(*))          as completion_rate,
        countif(disbursements.attempt_number > 1)                           as retry_attempts_count,
        safe_divide(countif(disbursements.attempt_number > 1), count(*))    as retry_rate,
        avg(if(disbursements.is_completed, disbursements.minutes_since_creation, null))
                                                                            as avg_minutes_to_complete,
        approx_quantiles(if(disbursements.is_completed, disbursements.minutes_since_creation, null), 100 ignore nulls)[offset(50)]
                                                                            as median_minutes_to_complete
    from disbursements
    inner join providers on disbursements.payout_provider_key = providers.payout_provider_key
    inner join corridors on disbursements.corridor_key = corridors.corridor_key
    inner join dates on disbursements.disbursement_created_date_key = dates.date_key
    group by 1, 2, 3, 4, 5, 6
)

select * from final
