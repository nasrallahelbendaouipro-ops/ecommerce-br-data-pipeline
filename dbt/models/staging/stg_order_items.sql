with

source as (

    select * from {{ source('raw', 'order_items') }}

),

renamed as (

    select
        nullif(order_id, '') as order_id,  
        nullif(product_id, '') as product_id,
        nullif(seller_id, '') as seller_id,
        cast(nullif(price, '') as numeric) as price,
        cast(nullif(shipping_charges, '') as numeric) as shipping_charges,
        load_type,
        load_date,

    from source

),

final as (

    select
        *
    from renamed

)

select * from final