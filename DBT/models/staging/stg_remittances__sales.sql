{{ config(
    materialized='view'
) }}

with 
source as (
    select 
        * 
    from {{ source('remittances', 'sales') }}
),

renamed as (

    select
        dia as day_sell,
        cantidad as quantity_sell,
        producto as priduct_id,
        precio as prize
    from source

)

select * from renamed