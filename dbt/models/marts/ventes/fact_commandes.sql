-- Une ligne par commande (1 commande = 1 article = 1 paiement dans ce jeu de données).
-- order_status est NULL pour les commandes du flux incrémental : aucune valeur inventée.
with

orders as (

    select * from {{ ref('stg_orders') }}

),

items as (

    select order_id, product_id, price, shipping_charges
    from {{ ref('stg_order_items') }}

),

payments as (

    select order_id, payment_type, payment_installments, payment_value
    from {{ ref('stg_payments') }}

),

final as (

    select
        orders.order_id,
        orders.customer_id,
        items.product_id,
        date(orders.order_purchase_timestamp) as purchase_date,
        orders.order_status,
        orders.is_outcome_unknown,
        items.price,
        items.shipping_charges,
        payments.payment_type,
        payments.payment_installments,
        payments.payment_value

    from orders
    left join items on orders.order_id = items.order_id
    left join payments on orders.order_id = payments.order_id

)

select * from final
