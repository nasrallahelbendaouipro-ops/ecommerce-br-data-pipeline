{{ config(severity='warn') }}

-- Anomalie connue de la source : quelques paiements avec 0 mensualité. Conservés tels quels, signalés ici.
select order_id, payment_installments
from {{ ref('stg_payments') }}
where payment_installments < 1
