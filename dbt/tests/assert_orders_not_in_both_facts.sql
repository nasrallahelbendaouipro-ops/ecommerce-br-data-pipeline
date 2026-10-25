-- Une commande est soit résolue (fact_expeditions), soit en cours (fact_commandes_en_cours), jamais les deux.
select expeditions.order_id
from {{ ref('fact_expeditions') }} as expeditions
inner join {{ ref('fact_commandes_en_cours') }} as en_cours
    on expeditions.order_id = en_cours.order_id
