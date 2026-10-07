{#- Integer date key (yyyymmdd, UTC) for a timestamp column; null stays null. -#}
{% macro date_key(column) -%}
    cast(format_date('%Y%m%d', date({{ column }})) as int64)
{%- endmacro %}
