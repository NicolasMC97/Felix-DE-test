-- One row per destination country + currency pair (a remittance corridor).
-- The same country can receive in local currency and in USD, so currency is part of the grain.
with
corridors as (
    select distinct
        destination_country_code as country_code,
        destination_currency     as currency_code
    from {{ ref('stg_remittances__receipts') }}
),

final as (
    select
        {{ generate_surrogate_key(['country_code', 'currency_code']) }} as corridor_key,
        country_code,
        case country_code
            when 'MX' then 'Mexico'
            when 'GT' then 'Guatemala'
            when 'HN' then 'Honduras'
            when 'SV' then 'El Salvador'
            when 'NI' then 'Nicaragua'
            when 'CR' then 'Costa Rica'
            when 'DO' then 'Dominican Republic'
            when 'CO' then 'Colombia'
            when 'EC' then 'Ecuador'
            when 'PE' then 'Peru'
            when 'BR' then 'Brazil'
            else 'Unknown'
        end                                                             as country_name,
        case
            when country_code = 'MX' then 'North America'
            when country_code in ('GT', 'HN', 'SV', 'NI', 'CR') then 'Central America'
            when country_code = 'DO' then 'Caribbean'
            when country_code in ('CO', 'EC', 'PE', 'BR') then 'South America'
            else 'Unknown'
        end                                                             as subregion,
        currency_code,
        currency_code = 'USD'                                           as is_usd_destination,
        concat(country_code, '-', currency_code)                        as corridor_name
    from corridors
)

select * from final
