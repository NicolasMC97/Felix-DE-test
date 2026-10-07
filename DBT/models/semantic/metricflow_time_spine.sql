-- Day-grain calendar required by MetricFlow (cumulative metrics, gap filling and time offsets).
select date_day
from {{ ref('dim_date') }}
