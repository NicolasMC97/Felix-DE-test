-- One row per normalized disbursement status with its status group.
with
statuses as (
    select distinct
        coalesce(status, 'UNKNOWN')        as disbursement_status,
        coalesce(status_group, 'UNKNOWN')  as status_group
    from {{ ref('stg_remittances__disbursements') }}
),

final as (
    select
        {{ generate_surrogate_key(['disbursement_status']) }} as disbursement_status_key,
        disbursement_status,
        status_group,
        status_group in ('COMPLETED', 'FAILED', 'CANCELLED')  as is_final
    from statuses
)

select * from final
