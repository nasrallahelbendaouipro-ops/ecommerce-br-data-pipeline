{{ config(severity='warn') }}

-- Anomalie connue de la source : quelques produits avec un poids à 0. Conservés tels quels, signalés ici.
select product_id, product_weight_g
from {{ ref('stg_products') }}
where product_weight_g <= 0
