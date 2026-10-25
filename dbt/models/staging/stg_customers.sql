with

source as (

    select * from {{ source('raw', 'customers') }}

),

renamed as (

    select
        nullif(customer_id, '') as customer_id,
        lpad(nullif(customer_zip_code_prefix, ''), 5, '0') as customer_zip_code_prefix,
        nullif(customer_city, '') as customer_city,
        nullif(customer_state, '') as customer_state,
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