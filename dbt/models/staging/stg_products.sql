with

source as (

    select * from {{ source('raw', 'products') }}

),

renamed as (

    select
        nullif(product_id, '') as product_id,
        nullif(product_category_name, '') as product_category_name,
        cast(nullif(product_weight_g, '') as numeric) as product_weight_g,
        cast(nullif(product_length_cm, '') as numeric) as product_length_cm,
        cast(nullif(product_height_cm, '') as numeric) as product_height_cm,
        cast(nullif(product_width_cm, '') as numeric) as product_width_cm,
        load_type,
        load_date

    from source

),

-- raw contient des doublons exacts (un produit par ligne de order_items) :
-- on garde une seule ligne par product_id, la plus ancienne livraison.
ranked as (

    select
        *,
        row_number() over (
            partition by product_id
            order by load_date, load_type
        ) as row_num

    from renamed

),

deduplicated as (

    select * except (row_num)
    from ranked
    where row_num = 1

)

select * from deduplicated
