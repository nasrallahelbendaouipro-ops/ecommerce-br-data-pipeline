-- Réconciliation : les jointures de fact_commandes ne doivent ni perdre ni dupliquer de commandes,
-- et le montant total des prix doit rester celui du staging.
select *
from (
    select
        (select count(*) from {{ ref('fact_commandes') }}) as fact_orders,
        (select count(*) from {{ ref('stg_orders') }}) as staging_orders,
        (select sum(price) from {{ ref('fact_commandes') }}) as fact_price,
        (select sum(price) from {{ ref('stg_order_items') }}) as staging_price
)
where fact_orders != staging_orders
    or fact_price != staging_price
