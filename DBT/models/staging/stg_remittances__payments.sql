{{ config(
    materialized='view'
) }}

with
source as (
    select * from {{ source('remittances', 'payments') }}
),

deduplicated as (
    select *
    from source
    qualify row_number() over (
        partition by id
        order by updated_at desc, created_at desc
    ) = 1
),

renamed as (
    select
        id                              as payment_id,
        user_id,
        amount                          as amount_usd,
        upper(currency)                 as currency,
        upper(status)                   as status,
        upper(detailed_status)          as status_detail,
        upper(type)                     as payment_method,
        total_intents,
        upper(location_of_request_state_code) as request_state_code,
        has_dispute_chargeback,
        created_at,
        updated_at
        -- error_code and reason are dropped: 100% null in the source
    from deduplicated
)

select * from renamed
