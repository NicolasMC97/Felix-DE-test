{{ config(
    materialized='view'
) }}

with
source as (
    select * from {{ source('remittances', 'disbursements') }}
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
        id                                  as disbursement_id,
        user_id,
        upper(type)                         as disbursement_method,
        upper(status)                       as status,
        upper(raw_status)                   as raw_status,
        provider_status,
        amount                              as amount_local,
        disbursement_provider               as provider,
        payer_destination_name              as payer_name,
        case
            when upper(trim(destination_country)) = 'COSTA RICA' then 'CR'
            else upper(trim(destination_country))
        end                                 as destination_country_code,
        upper(destination_currency)         as destination_currency,
        created_at,
        updated_at
    from deduplicated
),

status_mapped as (
    select
        *,
        -- Providers report with different vocabularies and casing (PAID / COMPLETED / Success, FAILED / Failed...).
        -- Anything not listed falls into UNMAPPED so the accepted_values test flags new statuses.
        case
            when status in ('PAID', 'COMPLETED', 'SUCCESS', 'DELIVERED')
                then 'COMPLETED'
            when status in ('FAILED', 'REJECTED', 'PAYOUT_NOT_PROCESSED', 'ERROR_SENDING_PAYOUT_REQUEST')
                then 'FAILED'
            when status in ('CANCELLED', 'CANCELLATION_IN_PROGRESS')
                then 'CANCELLED'
            when status in ('PAYABLE', 'IN_PROGRESS', 'PENDING', 'TO_BE_PROCESSED', 'TRANSMITTED', 'WIRE_RELEASED', 'WIRE_CONFIRMED')
                then 'IN_PROGRESS'
            when status in ('ON_HOLD', 'HOLD_BY_COMPLIANCE', 'HOLD_BY_PAYER')
                then 'ON_HOLD'
            else 'UNMAPPED'
        end as status_group
    from renamed
)

select * from status_mapped
