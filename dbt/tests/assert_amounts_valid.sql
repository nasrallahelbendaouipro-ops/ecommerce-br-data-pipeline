-- Plages de valeurs des montants (remplace accepted_range de dbt_utils).
select order_id, 'price <= 0' as regle
from {{ ref('stg_order_items') }}
where price <= 0

union all

select order_id, 'shipping_charges < 0' as regle
from {{ ref('stg_order_items') }}
where shipping_charges < 0

union all

select order_id, 'payment_value < 0' as regle
from {{ ref('stg_payments') }}
where payment_value < 0
