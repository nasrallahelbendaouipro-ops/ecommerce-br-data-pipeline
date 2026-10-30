-- Grain : une ligne par catégorie de produit et par mois d'achat.
-- La catégorie reste NULL quand elle est inconnue (pas de valeur inventée).
-- nb_orders compte toutes les commandes ; nb_orders_statut_connu exclut le flux incrémental
-- et sert de dénominateur aux taux : un taux d'annulation calculé sur nb_orders serait dilué
-- par 30 % de commandes dont l'issue est inconnue.
with

orders as (

    select * from {{ ref('fact_commandes') }}

),

products as (

    select product_id, product_category_name
    from {{ ref('dim_produit') }}

),

calendar as (

    select date_day, year_number, month_number, year_month
    from {{ ref('dim_date') }}

),

final as (

    select
        products.product_category_name,
        calendar.year_month,
        calendar.year_number,
        calendar.month_number,
        count(*) as nb_orders,
        countif(not orders.is_outcome_unknown) as nb_orders_statut_connu,
        countif(orders.order_status = 'canceled') as nb_orders_canceled,
        sum(orders.price) as total_price,
        avg(orders.price) as avg_price,
        sum(orders.payment_value) as total_payment_value

    from orders
    left join products on orders.product_id = products.product_id
    left join calendar on orders.purchase_date = calendar.date_day
    group by
        products.product_category_name,
        calendar.year_month,
        calendar.year_number,
        calendar.month_number

)

select * from final
