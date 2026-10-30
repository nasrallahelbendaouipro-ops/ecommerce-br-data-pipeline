-- Taux de retard historique par état du client, mesuré sur les commandes résolues uniquement.
-- Le seuil est relatif : un état est à risque s'il dépasse le taux national, recalculé ici
-- à chaque exécution (jamais codé en dur) et adossé à un volume minimal de livraisons.
with

expeditions as (

    select
        expeditions.is_late,
        clients.customer_state

    from {{ ref('fact_expeditions') }} as expeditions
    left join {{ ref('dim_client') }} as clients
        on expeditions.customer_id = clients.customer_id

),

national as (

    select countif(is_late) / count(*) as taux_retard_national
    from expeditions

),

agrege as (

    select
        customer_state,
        count(*) as nb_livraisons,
        countif(is_late) as nb_retards,
        countif(is_late) / count(*) as taux_retard

    from expeditions
    group by customer_state

),

final as (

    select
        agrege.customer_state,
        agrege.nb_livraisons,
        agrege.nb_retards,
        agrege.taux_retard,
        national.taux_retard_national,
        agrege.nb_livraisons >= {{ var('seuil_livraisons_etat') }} as is_scorable,
        agrege.nb_livraisons >= {{ var('seuil_livraisons_etat') }}
            and agrege.taux_retard > national.taux_retard_national as is_etat_a_risque

    from agrege
    cross join national

)

select * from final
