-- Le score géographique suppose que chaque état du flux entrant existe aussi dans l'historique.
-- Si ce test échoue, des commandes sont classées sans que leur état ait un taux de retard mesuré.
select order_id, taux_retard_etat
from {{ ref('fact_commandes_en_cours') }}
where taux_retard_etat is null
