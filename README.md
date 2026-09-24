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

- [ ] 00 · Cadrage & datasets
- [ ] 01 · Socle GCP
- [ ] 02 · Ingestion initiale (backfill train)
- [ ] 03 · Ingestion incrémentale (flux test simulé)
- [ ] 04 · dbt — staging
- [ ] 05 · dbt — marts
- [ ] 06 · Tests & qualité
- [ ] 07 · Orchestration Airflow
- [ ] 08 · Dashboard Power BI — Logistique & Livraison
- [ ] 09 · Dashboard Tableau — Ventes & Produits
- [ ] 10 · Documentation & portfolio

Feuille de route détaillée : [`docs/feuille-de-route.html`](docs/feuille-de-route.html) (à ouvrir dans un navigateur).

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
