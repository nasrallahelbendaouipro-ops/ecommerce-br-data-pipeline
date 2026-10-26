# Pipeline data e-commerce brésilien — GCP · dbt · Airflow

> ⚠️ Projet en cours de construction. Ce README est un squelette provisoire : la version finale (architecture expliquée, captures des dashboards, choix de conception) est l'objet de la phase 10.

Pipeline de données complet construit autour d'un dataset e-commerce brésilien livré en 5 tables relationnelles, avec un split train/test détourné en **flux d'ingestion réaliste** : le train sert de backfill historique, le test simule des commandes en cours, sans issue connue.

## Stack

| Étape | Outil |
|---|---|
| Stockage fichiers | Google Cloud Storage |
| Entrepôt | BigQuery |
| Transformation | dbt Core |
| Orchestration | Airflow (local, Docker Compose) |
| Restitution | Power BI (logistique) · Tableau (ventes) |

Contrainte : rester intégralement dans le niveau gratuit GCP.

## Le parti pris du projet

Le test set ne contient ni `order_status`, ni date de livraison réelle, ni date de livraison estimée — exactement les colonnes qu'on ignore tant qu'une commande n'est pas résolue. Plutôt que de l'écarter, il est injecté par batches comme un flux entrant. Ces commandes traversent donc le pipeline **sans statut ni date de livraison inventés**, et sont isolées des KPI historiques (un délai moyen calculé sur des commandes non livrées serait faux).

## Avancement

- [x] 00 · Cadrage & datasets
- [x] 01 · Socle GCP
- [x] 02 · Ingestion initiale (backfill train)
- [x] 03 · Ingestion incrémentale (flux test simulé)
- [x] 04 · dbt — staging
- [x] 05 · dbt — marts
- [x] 06 · Tests & qualité
- [x] 07 · Orchestration Airflow
- [ ] 08 · Dashboard Power BI — Logistique & Livraison
- [ ] 09 · Dashboard Tableau — Ventes & Produits
- [ ] 10 · Documentation & portfolio

Feuille de route détaillée : [`docs/feuille-de-route.html`](docs/feuille-de-route.html) (à ouvrir dans un navigateur).

## Ingestion incrémentale

Scénario : le rattrapage d'un système source non encore migré. Le jeu test est découpé en 24 lots mensuels (`scripts/decouper_lots_test.py`) stockés dans une zone `source/` du bucket, hors du pipeline. Chaque run du DAG quotidien livre un mois : il copie le lot de `source/test/<table>/mois=AAAA-MM/` vers `raw/<table>/load_type=incremental/load_date=<date du run>/`, puis lance `dbt run` et `dbt test`.

Les tables `raw` sont des tables externes BigQuery sur ces dossiers : déposer un fichier suffit, et rejouer un run réécrit le même fichier, sans doublon. Détail des choix : [`docs/decisions.md`](docs/decisions.md). DDL : `sql/raw/`, contrôles : `sql/controles/`.

## Orchestration (Airflow local)

Le DAG `ecommerce_br_incremental` (`airflow/dags/`) livre un lot mensuel par run quotidien : copie des 5 tables de `source/` vers `raw/`, puis `dbt run`, `dbt test` et une notification. Il tourne dans Docker Compose (LocalExecutor + PostgreSQL), avec dbt installé dans un environnement virtuel de l'image aux versions de `requirements.txt`.

Pour le lancer (Docker Desktop requis) :

1. Créer `airflow/.env` à partir de `airflow/.env.example`.
2. Placer la clé d'un compte de service dans `airflow/secrets/gcp-key.json` (dossier ignoré par git, jamais commité).
3. Depuis `airflow/` : `docker compose up -d`, puis ouvrir http://localhost:8080 et activer le DAG (il est créé en pause).

Avec `catchup=True`, les 24 runs (du 2 au 25 octobre 2026, un lot chacun) s'enchaînent d'un coup. Le mois livré se calcule depuis la date du run : un retry redonne le même lot, sans doublon. Détails : [`docs/decisions.md`](docs/decisions.md).

## Modélisation cible

```
models/
├── staging/                        1 modèle par table source, aucune jointure
└── marts/
    ├── shared/                     dim_date · dim_client · dim_produit
    ├── logistique/   → Power BI    fact_expeditions · fact_commandes_en_cours
    └── ventes/       → Tableau     fact_commandes · fact_ventes_categorie
```

## Données

Les CSV sources **ne sont pas versionnés** dans ce dépôt (voir `.gitignore`) : la source et la licence d'origine ne sont pas encore confirmées. Structure attendue en local :

```
Ecommerce Order Dataset/
├── train/   df_Orders.csv · df_OrderItems.csv · df_Customers.csv · df_Products.csv · df_Payments.csv
└── test/    (mêmes fichiers ; df_Orders.csv n'a que 4 colonnes)
```
