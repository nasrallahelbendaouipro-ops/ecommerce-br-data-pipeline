-- Commandes sans issue connue (flux incrémental : pas de statut, pas de date de livraison).
-- Aucun statut ni délai inventé ; l'ancienneté se mesure à une date de référence fixe, pas à CURRENT_DATE.
with

orders as (

    select *
    from {{ ref('stg_orders') }}
    where is_outcome_unknown

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
        orders.order_purchase_timestamp as purchase_at,
        orders.order_approved_at as approved_at,
        date(orders.order_purchase_timestamp) as purchase_date,
        date('{{ var("reference_date") }}') as reference_date,
        date_diff(date('{{ var("reference_date") }}'), date(orders.order_purchase_timestamp), day) as days_since_purchase

    from orders
    left join items on orders.order_id = items.order_id

)

select * from final
