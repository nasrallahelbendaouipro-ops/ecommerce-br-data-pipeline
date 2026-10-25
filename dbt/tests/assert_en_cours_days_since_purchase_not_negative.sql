-- La date de référence fixe doit être postérieure à toute commande en cours.
select order_id, purchase_date, reference_date, days_since_purchase
from {{ ref('fact_commandes_en_cours') }}
where days_since_purchase < 0
