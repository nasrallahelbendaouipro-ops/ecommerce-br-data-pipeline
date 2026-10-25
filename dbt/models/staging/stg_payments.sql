with

source as (

    select * from {{ source('raw', 'payments') }}

),

renamed as (

    select
        nullif(order_id, '') as order_id,
        cast(nullif(payment_sequential, '') as int64) as payment_sequential,
        nullif(payment_type, '') as payment_type,
        cast(nullif(payment_installments, '') as int64) as payment_installments,
        cast(nullif(payment_value, '') as numeric) as payment_value,
        load_type,
        load_date

    from source

)

select * from renamed