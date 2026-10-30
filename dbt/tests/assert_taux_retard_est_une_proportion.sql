-- Un taux de retard est une proportion : jamais en dehors de [0, 1].
select 'vendeur' as source, seller_id as cle, taux_retard
from {{ ref('int_taux_retard_vendeur') }}
where taux_retard < 0 or taux_retard > 1

union all

select 'etat' as source, customer_state as cle, taux_retard
from {{ ref('int_taux_retard_etat') }}
where taux_retard < 0 or taux_retard > 1
