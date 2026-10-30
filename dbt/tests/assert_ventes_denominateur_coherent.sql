-- Les taux des marts ventes se calculent sur les commandes à statut connu.
-- Deux invariants : le dénominateur ne peut pas dépasser le total, et une commande annulée
-- a forcément un statut connu, donc les annulations ne peuvent pas dépasser le dénominateur.
select 'categorie' as modele, nb_orders, nb_orders_statut_connu, nb_orders_canceled
from {{ ref('fact_ventes_categorie') }}
where nb_orders_statut_connu > nb_orders
    or nb_orders_canceled > nb_orders_statut_connu

union all

select 'paiement' as modele, nb_orders, nb_orders_statut_connu, nb_orders_canceled
from {{ ref('fact_ventes_paiement') }}
where nb_orders_statut_connu > nb_orders
    or nb_orders_canceled > nb_orders_statut_connu
