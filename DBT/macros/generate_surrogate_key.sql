{#- Hash surrogate key from a list of columns; nulls are made explicit so they do not collapse values. -#}
{% macro generate_surrogate_key(columns) -%}
    to_hex(md5(concat(
        {%- for column in columns -%}
            coalesce(cast({{ column }} as string), '_null_'){% if not loop.last %}, '|', {% endif %}
        {%- endfor -%}
    )))
{%- endmacro %}
