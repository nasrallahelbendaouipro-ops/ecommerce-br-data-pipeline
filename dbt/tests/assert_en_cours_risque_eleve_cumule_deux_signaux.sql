-- « élevé » est réservé au cumul des deux signaux historiques (vendeur à risque ET état à risque).
select order_id, niveau_risque, is_vendeur_a_risque, is_etat_a_risque
from {{ ref('fact_commandes_en_cours') }}
where niveau_risque = 'élevé'
    and not (is_vendeur_a_risque and is_etat_a_risque)
