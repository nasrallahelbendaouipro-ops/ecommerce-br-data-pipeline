-- Grain : une ligne par mois d'achat, état du client, type de paiement et nombre de mensualités.
-- Agrégat destiné à Tableau Public : uniquement des mesures additives (compteurs et sommes),
-- jamais de moyenne pré-calculée. Une LOD appliquée à une moyenne déjà agrégée donnerait une
-- moyenne de moyennes ; avec des sommes et des compteurs, Tableau recalcule correctement en
-- SUM / SUM. Aucune ligne au grain commande n'est donc publiée.
-- nb_orders compte toutes les commandes ; nb_orders_statut_connu exclut le flux incrémental et
-- sert de dénominateur aux taux (même règle que fact_ventes_categorie).
with

orders as (

    select * from {{ ref('fact_commandes') }}

),

clients as (

    select customer_id, customer_state
    from {{ ref('dim_client') }}

),

calendar as (

    select date_day, year_number, month_number, year_month
    from {{ ref('dim_date') }}

),

final as (

    select
        calendar.year_month,
        calendar.year_number,
        calendar.month_number,
        clients.customer_state,
        orders.payment_type,
        orders.payment_installments,
        count(*) as nb_orders,
        countif(not orders.is_outcome_unknown) as nb_orders_statut_connu,
        countif(orders.order_status = 'canceled') as nb_orders_canceled,
        sum(orders.price) as total_price,
        sum(orders.payment_value) as total_payment_value

    from orders
    left join clients on orders.customer_id = clients.customer_id
    left join calendar on orders.purchase_date = calendar.date_day
    group by
        calendar.year_month,
        calendar.year_number,
        calendar.month_number,
        clients.customer_state,
        orders.payment_type,
        orders.payment_installments

)

select * from final
