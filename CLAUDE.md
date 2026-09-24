# Projet — Pipeline data e-commerce BR (portfolio d'apprentissage)

Feuille de route détaillée (11 phases) : `C:\Users\Nasra\Downloads\ecommerce-br-feuille-de-route.html`

## Contexte

Projet personnel de data engineering pour portfolio, dans une logique **d'apprentissage**, pas de livraison rapide. Stack : GCP (Cloud Storage, BigQuery), dbt Core, Airflow (local via Docker Compose), Power BI, Tableau.

Ce projet a remplacé une version précédente basée sur le dataset DataCo Smart Supply Chain (un seul CSV plat). La nouvelle source est un dataset e-commerce brésilien fourni en 5 tables relationnelles avec un split train/test détourné en flux d'ingestion réaliste.

## ⚠️ Comment m'aider sur ce projet — lis ceci avant de coder quoi que ce soit

**Le but n'est pas d'avoir un pipeline fini, c'est de le construire moi-même et de comprendre chaque brique.** Je débute (j'ai commencé dbt Fundamentals récemment). Sur ce projet, ton rôle par défaut est de **guider, pas de résoudre à ma place** :

- Ne génère pas directement le code complet d'un modèle dbt, d'un DAG Airflow ou d'une requête SQL complexe dès que je te le demande. Pose-moi d'abord les questions de conception (grain, clés, gestion des nulls, nommage) et laisse-moi écrire une première version.
- Relis mon code après coup plutôt que de l'écrire à ma place : signale les erreurs, les pièges, les incohérences — explique *pourquoi* c'est un problème, ne te contente pas de corriger.
- Si je bloque vraiment ou demande explicitement "montre-moi comment faire", tu peux donner un exemple — mais reviens ensuite sur le principe général pour que je puisse le réappliquer seul ailleurs.
- Les décisions de conception déjà tranchées (section ci-dessous) ne sont **pas** à renégocier ni à "améliorer" de ta propre initiative — applique-les telles quelles. Si tu vois un vrai problème avec l'une d'elles, dis-le, mais laisse-moi trancher.
- Reste dans le niveau gratuit GCP à chaque étape — signale-moi si une commande ou une ressource risque de sortir du free tier (voir budget plus bas).

## Le dataset

5 tables relationnelles, dans `Ecommerce Order Dataset/{train,test}/df_*.csv` :

| Table | Colonnes | Lignes train | Lignes test |
|---|---|---|---|
| `Orders` | `order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_timestamp, order_estimated_delivery_date` | 89 316 | 38 280 (⚠️ seulement `order_id, customer_id, order_purchase_timestamp, order_approved_at` — pas de statut ni de dates de livraison) |
| `OrderItems` | `order_id, product_id, seller_id, price, shipping_charges` | 89 316 | 38 280 |
| `Customers` | `customer_id, customer_zip_code_prefix, customer_city, customer_state` | 89 316 | 38 280 |
| `Products` | `product_id, product_category_name, product_weight_g, product_length_cm, product_height_cm, product_width_cm` | 89 316 | 38 280 |
| `Payments` | `order_id, payment_sequential, payment_type, payment_installments, payment_value` | 89 316 | 38 280 |

Notes de qualité de données déjà identifiées :
- `product_category_name` : ~0,3 % de valeurs vides dans `Products`.
- `order_delivered_timestamp` : ~2,1 % de valeurs vides dans `Orders` (train) — commandes annulées/en cours.
- IDs (`order_id`, `customer_id`, `product_id`, `seller_id`) : chaînes alphanumériques aléatoires, pas des entiers.
- 1 commande = 1 ligne dans `OrderItems` dans ce jeu de données (pas de multi-articles par commande).
- Encodage propre (ASCII), pas de problème d'accents contrairement à l'ancien dataset DataCo.
- Aucun README dans l'archive fournie — source/licence d'origine non confirmée, à vérifier avant publication en portfolio public.

À vérifier en phase 00 : unicité de `product_id` dans `Products` et de `customer_id` dans `Customers` (mêmes volumes que `Orders`), et sens de `payment_sequential` dans `Payments` — impacte le grain de `dim_produit` / `dim_client`.

## Architecture décidée

### Flux d'ingestion (le cœur différenciant de ce projet)
- **Train = backfill historique**, chargé une fois dans des tables `raw_*`.
- **Test = flux entrant simulé**, chargé progressivement (par batches, idéalement en s'appuyant sur `order_purchase_timestamp`) pour donner un vrai cas d'usage à l'orchestration Airflow planifiée.
- Les lignes du test représentent des **commandes réellement en cours, sans issue connue** — ne jamais inventer un `order_status` ou une date de livraison pour elles, à aucune étape du pipeline.
- Backfill et flux incrémental sont chargés dans des tables/sources séparées, jamais mélangés en amont du staging.

### Marts (star schema, deux domaines métier)
```
models/marts/
├── shared/
│   ├── dim_date.sql
│   ├── dim_client.sql          (géographie : zip/city/state)
│   └── dim_produit.sql         (catégorie, poids, dimensions)
├── logistique/                 → alimente Power BI
│   ├── fact_expeditions.sql        (commandes résolues : retard, seller_id, shipping_charges)
│   └── fact_commandes_en_cours.sql (flux incrémental : statut inconnu, à traiter séparément)
└── ventes/                     → alimente Tableau
    ├── fact_commandes.sql          (price, payment_type/installments/value)
    └── fact_ventes_categorie.sql
```

- `seller_id` → rattaché au mart **logistique** (performance de livraison par vendeur), pas de dimension vendeur séparée.
- Données de paiement (`payment_type`, `payment_installments`, `payment_value`) → axe du mart **ventes**, pas de mart financier séparé.
- `dim_date`, `dim_client`, `dim_produit` → mutualisées dans `shared/`, référencées via `ref()` dans les deux marts. Ne jamais les dupliquer.
- Ne jamais mélanger commandes résolues (`fact_expeditions`) et commandes en cours (`fact_commandes_en_cours`) dans un même calcul de délai moyen — un résultat sans date de livraison fausse silencieusement la moyenne.

### Dashboards (structure proposée, pas encore figée — à confirmer avec moi avant de commencer les phases 08/09)

**Power BI — Logistique & Livraison** (DAX)
1. Vue d'ensemble (taux de retard, délai moyen, coût de port moyen, nb commandes en cours)
2. Géographie (retard par état/ville)
3. Vendeurs (`seller_id` à risque)
4. Commandes en cours (flux incrémental — détection de commandes "à risque" en comparant à la moyenne historique)

**Tableau — Ventes & Produits** (LOD expressions — pas de DAX, Tableau a son propre système de calcul)
1. Vue d'ensemble (volume/valeur, tendance)
2. Catégories & produits (top catégories, panier moyen via LOD `FIXED`)
3. Paiement & segmentation (répartition des modes de paiement/mensualités par région)
4. Statuts & annulations (taux d'annulation par catégorie, lien narratif avec les retards via `dim_date`)

## Les 11 phases (dans l'ordre)

00. **Cadrage & datasets** — comprendre les 5 tables et le train/test avant de coder.
01. **Socle GCP** — projet, IAM minimal, bucket GCS, dataset BigQuery, alerte de budget.
02. **Ingestion initiale (train)** — CSV → GCS → tables `raw_*` BigQuery, chargement unique.
03. **Ingestion incrémentale (test)** — flux simulé par batches, idempotent, reproductible.
04. **dbt staging** — 5 modèles `stg_*`, un par table source, aucune jointure.
05. **dbt marts** — assembler en `shared/` + `logistique/` + `ventes/` (voir architecture ci-dessus).
06. **Tests & qualité** — tests génériques dbt (`not_null`, `unique`, `relationships`, `accepted_range`) + tests custom sur les règles métier (délai jamais négatif, flux incrémental sans statut).
07. **Orchestration Airflow** — DAG(s) gérant backfill (one-shot) + incrémental (planifié), enchaînant extraction → chargement → `dbt run` → `dbt test` → notification.
08. **Dashboard Power BI — Logistique & Livraison**.
09. **Dashboard Tableau — Ventes & Produits**.
10. **Documentation & portfolio** — README expliquant l'architecture, le choix du flux incrémental, et le remplacement de DataCo.

## Budget — rester à 0 €

- Cloud Storage, BigQuery (stockage + requêtes), Cloud Run functions, Cloud Scheduler : gratuits à cette échelle (~127 000 lignes).
- **Cloud Composer (Airflow managé) : payant même à l'arrêt — ne pas l'utiliser.** Airflow tourne en local via Docker Compose.
- dbt Core : gratuit (CLI, local).
- Power BI Desktop, Tableau Public : gratuits. Éviter Power BI Pro et Tableau Desktop sauf besoin explicite de partage en ligne.
