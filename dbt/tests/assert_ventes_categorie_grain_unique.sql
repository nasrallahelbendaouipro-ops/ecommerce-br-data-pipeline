-- Grain de fact_ventes_categorie : une ligne par catégorie et par mois d'achat.
select product_category_name, year_month, count(*) as nb_lignes
from {{ ref('fact_ventes_categorie') }}
group by product_category_name, year_month
having count(*) > 1
