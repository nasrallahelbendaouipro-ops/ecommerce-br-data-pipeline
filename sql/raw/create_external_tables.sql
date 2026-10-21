-- Tables externes de la couche raw (phase 03).
-- Elles ont été créées via la console BigQuery ; ce fichier sert de référence reproductible.
-- Toutes les colonnes de données sont en STRING (le typage se fait dans le staging dbt).
-- load_type et load_date sont déduites du chemin GCS (format Hive) :
--   raw/<table>/load_type=initial|incremental/load_date=AAAA-MM-JJ/<table>.csv
-- BigQuery lit les CSV par position : l'ordre des colonnes ci-dessous doit être celui des fichiers.

CREATE OR REPLACE EXTERNAL TABLE `sonorous-lyceum-506109-a5.raw.orders` (
  order_id STRING,
  customer_id STRING,
  order_status STRING,
  order_purchase_timestamp STRING,
  order_approved_at STRING,
  order_delivered_timestamp STRING,
  order_estimated_delivery_date STRING
)
WITH PARTITION COLUMNS (load_type STRING, load_date DATE)
OPTIONS (
  format = 'CSV',
  uris = ['gs://e-commerce-brz/raw/orders/*'],
  hive_partition_uri_prefix = 'gs://e-commerce-brz/raw/orders/',
  skip_leading_rows = 1
);

CREATE OR REPLACE EXTERNAL TABLE `sonorous-lyceum-506109-a5.raw.order_items` (
  order_id STRING,
  product_id STRING,
  seller_id STRING,
  price STRING,
  shipping_charges STRING
)
WITH PARTITION COLUMNS (load_type STRING, load_date DATE)
OPTIONS (
  format = 'CSV',
  uris = ['gs://e-commerce-brz/raw/order_items/*'],
  hive_partition_uri_prefix = 'gs://e-commerce-brz/raw/order_items/',
  skip_leading_rows = 1
);

CREATE OR REPLACE EXTERNAL TABLE `sonorous-lyceum-506109-a5.raw.payments` (
  order_id STRING,
  payment_sequential STRING,
  payment_type STRING,
  payment_installments STRING,
  payment_value STRING
)
WITH PARTITION COLUMNS (load_type STRING, load_date DATE)
OPTIONS (
  format = 'CSV',
  uris = ['gs://e-commerce-brz/raw/payments/*'],
  hive_partition_uri_prefix = 'gs://e-commerce-brz/raw/payments/',
  skip_leading_rows = 1
);

CREATE OR REPLACE EXTERNAL TABLE `sonorous-lyceum-506109-a5.raw.customers` (
  customer_id STRING,
  customer_zip_code_prefix STRING,
  customer_city STRING,
  customer_state STRING
)
WITH PARTITION COLUMNS (load_type STRING, load_date DATE)
OPTIONS (
  format = 'CSV',
  uris = ['gs://e-commerce-brz/raw/customers/*'],
  hive_partition_uri_prefix = 'gs://e-commerce-brz/raw/customers/',
  skip_leading_rows = 1
);

CREATE OR REPLACE EXTERNAL TABLE `sonorous-lyceum-506109-a5.raw.products` (
  product_id STRING,
  product_category_name STRING,
  product_weight_g STRING,
  product_length_cm STRING,
  product_height_cm STRING,
  product_width_cm STRING
)
WITH PARTITION COLUMNS (load_type STRING, load_date DATE)
OPTIONS (
  format = 'CSV',
  uris = ['gs://e-commerce-brz/raw/products/*'],
  hive_partition_uri_prefix = 'gs://e-commerce-brz/raw/products/',
  skip_leading_rows = 1
);
