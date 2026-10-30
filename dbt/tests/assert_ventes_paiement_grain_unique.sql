-- Grain : une ligne par mois d'achat, état, type de paiement et nombre de mensualités.
select year_month, customer_state, payment_type, payment_installments, count(*) as n
from {{ ref('fact_ventes_paiement') }}
group by year_month, customer_state, payment_type, payment_installments
having count(*) > 1
