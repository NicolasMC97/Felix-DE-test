-- Day-grain calendar required by MetricFlow (cumulative metrics, gap filling and time offsets).
-- Timestamp type so it compares with the timestamp truncations MetricFlow generates on BigQuery.
select timestamp(date_day) as date_day
from {{ ref('dim_date') }}
