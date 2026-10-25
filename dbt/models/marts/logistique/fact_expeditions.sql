-- Commandes résolues uniquement : statut delivered ET date de livraison renseignée.
-- Ne jamais y mélanger les commandes en cours (voir fact_commandes_en_cours).
with

orders as (

    select *
    from {{ ref('stg_orders') }}
    where order_status = 'delivered'
        and order_delivered_timestamp is not null

),

items as (

    select order_id, seller_id, shipping_charges
    from {{ ref('stg_order_items') }}

),

final as (

    select
        orders.order_id,
        orders.customer_id,
        items.seller_id,
        items.shipping_charges,
        date(orders.order_purchase_timestamp) as purchase_date,
        date(orders.order_delivered_timestamp) as delivered_date,
        orders.order_estimated_delivery_date as estimated_delivery_date,
        date_diff(date(orders.order_delivered_timestamp), date(orders.order_purchase_timestamp), day) as delivery_days,
        date_diff(date(orders.order_delivered_timestamp), orders.order_estimated_delivery_date, day) as delivery_delay_days,
        date(orders.order_delivered_timestamp) > orders.order_estimated_delivery_date as is_late

    from orders
    left join items on orders.order_id = items.order_id

)

select * from final
