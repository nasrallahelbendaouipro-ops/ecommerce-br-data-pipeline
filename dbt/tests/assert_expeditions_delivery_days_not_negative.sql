-- Un délai (achat -> livraison) ne peut jamais être négatif.
-- delivery_delay_days (livraison - date estimée) peut l'être légitimement : livraison en avance.
select order_id, delivery_days
from {{ ref('fact_expeditions') }}
where delivery_days < 0
