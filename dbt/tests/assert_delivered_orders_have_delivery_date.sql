{{ config(severity='warn') }}

-- Anomalie connue de la source : des commandes "delivered" sans date de livraison.
-- Elles sont exclues de fact_expeditions ; on les signale ici sans bloquer le pipeline.
select order_id
from {{ ref('stg_orders') }}
where order_status = 'delivered'
    and order_delivered_timestamp is null
