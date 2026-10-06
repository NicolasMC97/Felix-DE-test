{{ config(
    materialized='view'
) }}

with
source as (
    select * from {{ source('remittances', 'receipts') }}
),

deduplicated as (
    select *
    from source
    qualify row_number() over (
        partition by id
        order by created_at desc
    ) = 1
),

renamed as (
    select
        id                                  as receipt_id,
        user_id,
        payment_id,
        disbursement_id,
        beneficiary_id,
        upper(destination_country_code)     as destination_country_code,
        upper(destination_currency)         as destination_currency,
        amount_charged                      as amount_charged_usd,
        fee                                 as fee_usd,
        exchange_rate,
        promotion_amount                    as promotion_amount_usd,
        destination_amount                  as destination_amount_local,
        created_at
    from deduplicated
)

select * from renamed
