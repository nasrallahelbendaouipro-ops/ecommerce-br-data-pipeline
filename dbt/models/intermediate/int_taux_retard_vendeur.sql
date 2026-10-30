-- Taux de retard historique par vendeur, mesuré sur les commandes résolues uniquement.
-- Sert à qualifier le flux entrant sans mélanger les délais des deux faits : seul un taux
-- déjà mesuré est transmis, aucun délai n'est recalculé sur les commandes sans issue connue.
-- Un vendeur n'est « scorable » qu'au-delà d'un volume minimal : en dessous, le taux existe
-- mais n'est pas assez solide pour qualifier une commande.
with

expeditions as (

    select seller_id, is_late
    from {{ ref('fact_expeditions') }}

),

agrege as (

    select
        seller_id,
        count(*) as nb_livraisons,
        countif(is_late) as nb_retards,
        countif(is_late) / count(*) as taux_retard

    from expeditions
    group by seller_id

),

final as (

    select
        seller_id,
        nb_livraisons,
        nb_retards,
        taux_retard,
        nb_livraisons >= {{ var('seuil_livraisons_vendeur') }} as is_scorable,
        nb_livraisons >= {{ var('seuil_livraisons_vendeur') }}
            and taux_retard >= {{ var('seuil_taux_retard_vendeur') }} as is_vendeur_a_risque

    from agrege

)

select * from final
