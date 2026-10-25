with

source as (

    select * from {{ source('raw', 'orders') }}

),

renamed as (

    select
        order_id,
        customer_id,
        nullif(order_status, '') as order_status,
        cast(nullif(order_purchase_timestamp, '') as datetime) as order_purchase_timestamp,
        cast(nullif(order_approved_at, '') as datetime) as order_approved_at,
        cast(nullif(order_delivered_timestamp, '') as datetime) as order_delivered_timestamp,
        cast(nullif(order_estimated_delivery_date, '') as date) as order_estimated_delivery_date,
        load_type,
        load_date

    from source

),

final as (

    select
        *,
        order_status is null as is_outcome_unknown

    from renamed

)

select * from final