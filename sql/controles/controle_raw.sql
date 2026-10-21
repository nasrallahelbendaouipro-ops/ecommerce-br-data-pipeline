-- Contrôle de la couche raw : lignes par table, load_type et load_date.
-- Attendu (validation phase 03) : initial / 2026-10-07 = 89 316 et incremental / 2026-10-14 = 113 pour chaque table.
SELECT 'orders' AS table_name, load_type, load_date, COUNT(*) AS nb_lignes
FROM `sonorous-lyceum-506109-a5.raw.orders` GROUP BY load_type, load_date
UNION ALL
SELECT 'order_items', load_type, load_date, COUNT(*)
FROM `sonorous-lyceum-506109-a5.raw.order_items` GROUP BY load_type, load_date
UNION ALL
SELECT 'payments', load_type, load_date, COUNT(*)
FROM `sonorous-lyceum-506109-a5.raw.payments` GROUP BY load_type, load_date
UNION ALL
SELECT 'customers', load_type, load_date, COUNT(*)
FROM `sonorous-lyceum-506109-a5.raw.customers` GROUP BY load_type, load_date
UNION ALL
SELECT 'products', load_type, load_date, COUNT(*)
FROM `sonorous-lyceum-506109-a5.raw.products` GROUP BY load_type, load_date
ORDER BY table_name, load_type, load_date;

-- orders, lots incrémentaux : order_purchase_timestamp rempli partout, order_status vide partout.
-- Attendu : nb_purchase_renseignes = nb_lignes et nb_status_renseignes = 0.
-- (Un champ CSV vide est lu comme chaîne vide en STRING, d'où le NULLIF.)
SELECT
  load_date,
  COUNT(*) AS nb_lignes,
  COUNTIF(NULLIF(order_purchase_timestamp, '') IS NOT NULL) AS nb_purchase_renseignes,
  COUNTIF(NULLIF(order_status, '') IS NOT NULL) AS nb_status_renseignes
FROM `sonorous-lyceum-506109-a5.raw.orders`
WHERE load_type = 'incremental'
GROUP BY load_date
ORDER BY load_date;
