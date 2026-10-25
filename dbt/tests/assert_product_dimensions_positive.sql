-- Les dimensions d'un produit physique doivent être strictement positives.
select product_id
from {{ ref('stg_products') }}
where product_length_cm <= 0
    or product_height_cm <= 0
    or product_width_cm <= 0
