{{ config(
    materialized='table'
) }}

-- Calendar covering the full range of the source data (2026-01-01 to 2026-09-22) rounded up to year end.
with
date_spine as (
    select date_day
    from unnest(generate_date_array('2026-01-01', '2026-12-31', interval 1 day)) as date_day
),

final as (
    select
        cast(format_date('%Y%m%d', date_day) as int64)      as date_key,
        date_day,
        extract(year from date_day)                         as year,
        extract(quarter from date_day)                      as quarter,
        extract(month from date_day)                        as month,
        format_date('%B', date_day)                         as month_name,
        date_trunc(date_day, month)                         as month_start_date,
        format_date('%Y-%m', date_day)                      as year_month,
        extract(isoweek from date_day)                      as week_of_year,
        date_trunc(date_day, isoweek)                       as week_start_date,
        extract(day from date_day)                          as day_of_month,
        -- ISO day of week: 1 = Monday ... 7 = Sunday (BigQuery dayofweek is 1 = Sunday)
        mod(extract(dayofweek from date_day) + 5, 7) + 1    as day_of_week,
        format_date('%A', date_day)                         as day_name,
        extract(dayofweek from date_day) in (1, 7)          as is_weekend,
        date_day = last_day(date_day, month)                as is_month_end
    from date_spine
)

select * from final
