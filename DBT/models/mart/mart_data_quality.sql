-- Data quality monitor: one row per month, check and issue type, with the share of affected records.
-- Months are the creation month of the record. New checks are added as another union branch.
with
transfers as (
    select * from {{ ref('fct_transfers') }}
),

payments as (
    select * from {{ ref('fct_payments') }}
),

disbursements as (
    select * from {{ ref('fct_disbursements') }}
),

transfer_totals as (
    select date_trunc(date(payment_created_at), month) as month, count(*) as total_records
    from transfers
    group by 1
),

payment_totals as (
    select date_trunc(date(created_at), month) as month, countif(is_successful) as total_successful
    from payments
    group by 1
),

disbursement_totals as (
    select date_trunc(date(created_at), month) as month, count(*) as total_records
    from disbursements
    group by 1
),

amount_mismatch as (
    select
        date_trunc(date(payment_created_at), month)     as month,
        'AMOUNT_MISMATCH'                               as check_name,
        amount_mismatch_type                            as issue_type,
        count(*)                                        as affected_records,
        sum(amount_diff_usd)                            as net_diff_usd,
        sum(abs(amount_diff_usd))                       as abs_diff_usd
    from transfers
    where has_amount_mismatch
    group by 1, 2, 3
),

missing_disbursement as (
    select
        date_trunc(date(payment_created_at), month)     as month,
        'RECEIPT_WITHOUT_DISBURSEMENT'                  as check_name,
        'MISSING_FK'                                    as issue_type,
        count(*)                                        as affected_records,
        sum(payment_amount_usd)                         as net_diff_usd,
        sum(payment_amount_usd)                         as abs_diff_usd
    from transfers
    where not has_disbursement
    group by 1, 2, 3
),

failed_with_receipt as (
    select
        date_trunc(date(payment_created_at), month)     as month,
        'FAILED_PAYMENT_WITH_RECEIPT'                   as check_name,
        'STATUS_CONFLICT'                               as issue_type,
        count(*)                                        as affected_records,
        sum(payment_amount_usd)                         as net_diff_usd,
        sum(payment_amount_usd)                         as abs_diff_usd
    from transfers
    where payment_status = 'FAILED'
    group by 1, 2, 3
),

payout_not_created as (
    select
        date_trunc(date(created_at), month)             as month,
        'SUCCESSFUL_PAYMENT_WITHOUT_RECEIPT'            as check_name,
        'PAYOUT_NOT_CREATED'                            as issue_type,
        count(*)                                        as affected_records,
        sum(amount_usd)                                 as net_diff_usd,
        sum(amount_usd)                                 as abs_diff_usd
    from payments
    where is_payout_not_created
    group by 1, 2, 3
),

invalid_disbursement_timestamps as (
    select
        date_trunc(date(created_at), month)             as month,
        'DISBURSEMENT_TIMESTAMPS'                       as check_name,
        if(updated_at is null, 'UPDATED_AT_NULL', 'UPDATED_BEFORE_CREATED') as issue_type,
        count(*)                                        as affected_records,
        cast(null as numeric)                           as net_diff_usd,
        cast(null as numeric)                           as abs_diff_usd
    from disbursements
    where updated_at is null or updated_at < created_at
    group by 1, 2, 3
),

issues as (
    select *, 'TRANSFERS' as population from amount_mismatch
    union all select *, 'TRANSFERS' from missing_disbursement
    union all select *, 'TRANSFERS' from failed_with_receipt
    union all select *, 'SUCCESSFUL_PAYMENTS' from payout_not_created
    union all select *, 'DISBURSEMENTS' from invalid_disbursement_timestamps
),

final as (
    select
        issues.month,
        issues.check_name,
        issues.issue_type,
        issues.population,
        issues.affected_records,
        case issues.population
            when 'TRANSFERS' then transfer_totals.total_records
            when 'SUCCESSFUL_PAYMENTS' then payment_totals.total_successful
            when 'DISBURSEMENTS' then disbursement_totals.total_records
        end                                             as total_records,
        safe_divide(
            issues.affected_records,
            case issues.population
                when 'TRANSFERS' then transfer_totals.total_records
                when 'SUCCESSFUL_PAYMENTS' then payment_totals.total_successful
                when 'DISBURSEMENTS' then disbursement_totals.total_records
            end
        )                                               as affected_pct,
        issues.net_diff_usd,
        issues.abs_diff_usd
    from issues
    left join transfer_totals on issues.month = transfer_totals.month
    left join payment_totals on issues.month = payment_totals.month
    left join disbursement_totals on issues.month = disbursement_totals.month
)

select * from final
