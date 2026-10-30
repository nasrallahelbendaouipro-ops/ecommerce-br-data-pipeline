-- Commandes sans issue connue (flux incrémental : pas de statut, pas de date de livraison).
-- Aucun statut ni délai inventé ; l'ancienneté se mesure à une date de référence fixe, pas à CURRENT_DATE.
-- Le niveau de risque n'est pas un pronostic de livraison : il reporte sur chaque commande les taux
-- de retard déjà mesurés sur l'historique (vendeur, état). « indéterminé » signifie « aucun signal
-- exploitable » : vendeur sous le volume minimal et état sous le taux national. Un signal positif
-- connu prime toujours sur une information manquante.
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

clients as (

    select customer_id, customer_state
    from {{ ref('dim_client') }}

),

risque_vendeur as (

    select seller_id, taux_retard, is_scorable, is_vendeur_a_risque
    from {{ ref('int_taux_retard_vendeur') }}

),

risque_etat as (

    select customer_state, taux_retard, is_etat_a_risque
    from {{ ref('int_taux_retard_etat') }}

),

joint as (

    select
        orders.order_id,
        orders.customer_id,
        items.seller_id,
        items.shipping_charges,
        orders.order_purchase_timestamp as purchase_at,
        orders.order_approved_at as approved_at,
        date(orders.order_purchase_timestamp) as purchase_date,
        date('{{ var("reference_date") }}') as reference_date,
        date_diff(date('{{ var("reference_date") }}'), date(orders.order_purchase_timestamp), day) as days_since_purchase,
        risque_vendeur.taux_retard as taux_retard_vendeur,
        coalesce(risque_vendeur.is_scorable, false) as is_vendeur_scorable,
        risque_vendeur.is_vendeur_a_risque,
        risque_etat.taux_retard as taux_retard_etat,
        risque_etat.is_etat_a_risque

    from orders
    left join items on orders.order_id = items.order_id
    left join clients on orders.customer_id = clients.customer_id
    left join risque_vendeur on items.seller_id = risque_vendeur.seller_id
    left join risque_etat on clients.customer_state = risque_etat.customer_state

),

classe as (

    select
        *,
        case
            when is_vendeur_a_risque and is_etat_a_risque then 'élevé'
            when is_vendeur_a_risque or is_etat_a_risque then 'modéré'
            when not is_vendeur_scorable then 'indéterminé'
            else 'faible'
        end as niveau_risque

    from joint

),

final as (

    select
        *,
        case niveau_risque
            when 'élevé' then 1
            when 'modéré' then 2
            when 'faible' then 3
            else 4
        end as niveau_risque_ordre

    from classe

)

select * from final
