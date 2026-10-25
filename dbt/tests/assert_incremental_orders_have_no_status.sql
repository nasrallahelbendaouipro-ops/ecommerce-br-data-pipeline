-- Le flux incrémental représente des commandes sans issue connue :
-- ni statut ni date de livraison ne doivent jamais y apparaître (rien n'est inventé).
select order_id, order_status, order_delivered_timestamp
from {{ ref('stg_orders') }}
where load_type = 'incremental'
    and (order_status is not null or order_delivered_timestamp is not null)
