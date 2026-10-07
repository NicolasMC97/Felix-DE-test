-- One row per provider + payer (paying institution at destination) + payout method.
with
payers as (
    select distinct
        coalesce(provider, 'UNKNOWN')            as provider,
        coalesce(payer_name, 'UNKNOWN')          as payer_name,
        coalesce(disbursement_method, 'UNKNOWN') as disbursement_method
    from {{ ref('stg_remittances__disbursements') }}
),

final as (
    select
        {{ generate_surrogate_key(['provider', 'payer_name', 'disbursement_method']) }} as payout_provider_key,
        provider,
        payer_name,
        disbursement_method
    from payers
)

select * from final
