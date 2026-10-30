-- « indéterminé » signifie « aucun signal exploitable » : le vendeur n'atteint pas le volume minimal
-- et l'état n'est pas à risque. Une commande classée ainsi alors qu'un signal existe serait sous-estimée.
select order_id, niveau_risque, is_vendeur_scorable, is_etat_a_risque
from {{ ref('fact_commandes_en_cours') }}
where niveau_risque = 'indéterminé'
    and (is_vendeur_scorable or coalesce(is_etat_a_risque, false))
