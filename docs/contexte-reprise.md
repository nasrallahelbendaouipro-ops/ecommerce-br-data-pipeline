# Contexte de reprise : pipeline e-commerce brésilien

> État au 30/10/2026. Fichier de passation pour une nouvelle session. À lire avec `CLAUDE.md` (règles du projet) avant toute action.
> Ne contient aucun secret. La clé GCP n'est jamais dans le dépôt.

## 1. Façon de travailler avec moi

- Réponds en **français**.
- Par défaut : **guider, ne pas résoudre à ma place** (voir `CLAUDE.md`). Questions de conception d'abord, relecture de mon code ensuite.
- Exception récente : depuis la phase 05, j'ai souvent demandé « fais-le pour moi » pour les modèles dbt, Airflow et le dashboard Power BI. Si je demande explicitement de faire, fais-le ; sinon, propose et attends.
- **Aucun commit ni push sans mon accord explicite.** Pas de ligne `Co-Authored-By` dans les commits (demande expresse).
- **Ne touche à aucun secret ni credential** (clé de compte de service, `.env`, jetons). Je les crée moi-même ; tu ne vérifies que l'existence et la taille d'un fichier, sans l'ouvrir.
- **Rester à 0 € sur GCP** : signale tout ce qui peut sortir du free tier.
- Je préfère la **console Google Cloud** au CLI quand c'est possible. Pour les choix, les **questions à choix multiples** m'aident.
- Avant de modifier des fichiers du projet Power BI : **Power BI Desktop doit être fermé** (il réécrit tous les fichiers à l'enregistrement et écraserait tes changements). Fais une copie de sécurité d'abord.

## 2. Avancement

| Phase | État |
|---|---|
| 00 Cadrage, 01 Socle GCP, 02 Ingestion initiale (train), 03 Ingestion incrémentale (test) | Terminées |
| 04 dbt staging, 05 dbt marts, 06 Tests et qualité | Terminées, commitées et poussées |
| 07 Orchestration Airflow | Terminée, commitée et poussée (`35b907f`). Les 24 runs ont réussi |
| 08 Dashboard Power BI (logistique) | **Construit, non commité**. Les 4 pages existent ; je les ai retouchées. README : case 08 pas encore cochée |
| 09 Dashboard Tableau (ventes) | **À faire** |
| 10 Documentation et portfolio | **À faire** |

Dernier commit poussé : `6ea1d79` (phase 08, premier jet). Branche `main` = `origin/main`. Tout le travail Power BI depuis (thème sombre, 3 pages, carte, mesures, fond) est **non commité** : voir §8.

## 3. Données et licence

- Source : Kaggle `bytadit/ecommerce-order-dataset`, licence **CC BY-NC-SA 4.0** (attribution, non commercial, partage dans les mêmes conditions). Mentionnée dans `README.md`, `docs/decisions.md` et `CLAUDE.md`.
- **Ne jamais publier** : les CSV, les `.pbix`, le cache Power BI (`.pbi/cache.abf`), ni d'export des marts. Code et captures d'écran avec attribution uniquement. Tout cela est dans `.gitignore`.
- Train : 89 316 commandes (backfill). Test : 38 279 commandes (flux incrémental, **sans** statut ni date de livraison : ne jamais en inventer).

## 4. GCP

- Projet `sonorous-lyceum-506109-a5`, région `us-central1`, bucket `e-commerce-brz`.
- Datasets BigQuery : `raw` (5 tables **externes** sur `gs://e-commerce-brz/raw/<table>/*`, partitionnement Hive `load_type`, `load_date`, colonnes en STRING), `staging` (5 vues `stg_*`), `marts` (7 tables).
- Convention GCS : `raw/<table>/load_type=initial|incremental/load_date=AAAA-MM-JJ/<table>.csv`. Lots non livrés dans `source/test/<table>/mois=AAAA-MM/`.
- Compte de service `ecommerce-br-data-pipeline` (Storage Object Admin, BigQuery Data Editor, BigQuery Job User). Clé JSON locale : `airflow/secrets/gcp-key.json` (ignorée par git). La règle d'organisation `iam.disableServiceAccountKeyCreation` a été levée le temps de créer la clé, puis **rétablie** (héritage du parent). **À la fin du projet : supprimer la clé** (IAM > Comptes de service > Clés).
- Volumes finaux : `stg_orders` 127 595 lignes ; `fact_expeditions` 87 422 ; `fact_commandes_en_cours` 38 279 ; `dim_client` 127 595 ; `dim_produit` 32 951 ; `dim_date` 1 096.

## 5. dbt

- dbt **Core 1.12.6** + `dbt-bigquery 1.12.1`, versions figées dans `requirements.txt`, dans le `.venv` à la racine.
- Piège : un **dbt global (Fusion 2.x)** existe dans `C:\Users\Nasra\.local\bin`. Active toujours le `.venv` (`.venv\Scripts\Activate.ps1`) et lance dbt **depuis le dossier `dbt/`**. L'extension VS Code est réglée sur le dbt du `.venv`.
- Profil dev : `C:\Users\Nasra\.dbt\profiles.yml` (oauth, dataset `staging`, `location: us-central1`). Hors dépôt.
- Macro `generate_schema_name` : les modèles `marts` vont dans `marts`, le reste dans `staging`.
- Marts : `shared/` (`dim_client`, `dim_produit`, `dim_date`), `logistique/` (`fact_expeditions`, `fact_commandes_en_cours`), `ventes/` (`fact_commandes`, `fact_ventes_categorie`).
- Décisions clés (détail dans `docs/decisions.md`) : commande résolue = statut `delivered` **et** date de livraison non nulle ; `reference_date` fixe `2018-09-03` (variable dbt) ; calendrier 2016-01-01 à 2018-12-31 ; `dim_client` et `dim_produit` sans `load_type` ni `load_date` ; `payment_sequential` non repris.
- Tests : 60 (57 réussis, **3 avertissements attendus** : 6 `delivered` sans date, 4 poids à 0, 3 paiements à 0 mensualité), 0 échec.

## 6. Airflow

- `airflow/` : `Dockerfile` (image Airflow 3.3.2 + venv dbt aux versions de `requirements.txt`), `docker-compose.yaml` (LocalExecutor + PostgreSQL, interface sur `127.0.0.1:8080`, connexion `airflow` / `airflow`), `dbt_profiles/profiles.yml` (compte de service, sans secret), `dags/ecommerce_br_incremental.py`.
- DAG `ecommerce_br_incremental` : `start_date` 2026-10-02, 24 runs quotidiens, `catchup=True`, `max_active_runs=1`. Chaque run : copie du lot mensuel de `source/` vers `raw/`, `dbt run`, `dbt test`, notification. **Les 24 runs sont terminés avec succès.**
- Pour relancer : Docker Desktop doit tourner (il est actuellement arrêté), puis depuis `airflow/` : `docker compose up -d`.
- Fichier local `airflow/.env` (ignoré) : contient le **proxy interne de Docker Desktop** (`HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`), nécessaire parce que les conteneurs n'ont pas d'accès Internet direct sur mon réseau. Modèle : `airflow/.env.example`.
- Dans un terminal PowerShell, `docker` n'est pas toujours dans le PATH : ajoute `C:\Program Files\Docker\Docker\resources\bin`.

## 7. Power BI (phase 08)

Projet au format **PBIP** : `Dashboards/Power BI/logistique.pbip` (fichiers texte : `logistique.Report`, `logistique.SemanticModel`). Le `.pbix` voisin fait doublon et est ignoré par git.

**Modèle** : tables `fact_expeditions`, `fact_commandes_en_cours`, `dim_date` (marquée table de dates), `dim_client` (avec colonne calculée `Pays` = "Brazil", catégories géographiques), `_Mesures`. Relations : `dim_date` vers `fact_expeditions[delivered_date]` (**active**), `[purchase_date]` et `[estimated_delivery_date]` (**inactives**, via `USERELATIONSHIP`), `dim_date` vers `fact_commandes_en_cours[purchase_date]` (active), `dim_client[customer_id]` vers les deux faits. Date/heure automatique désactivée. Import (pas DirectQuery), `BillingProject` renseigné.

**Mesures** (`_Mesures`) : Commandes livrées, Taux de retard, Délai moyen (jours), Coût de port moyen, Commandes en cours, Délai moyen par achat, Livrées par achat, Vendeurs actifs, Vendeurs à risque (≥ 30 livraisons et ≥ 15 % de retard, soit 40 vendeurs), Ancienneté moyenne (jours), Ancienneté max (jours), Date de référence.

**Pages** (canevas 1920 × 1080) : Vue d'ensemble, Géographie (carte du Brésil au niveau ville, barres par état, tableau des villes), Vendeurs (nuage, tableau classé par taux de retard), Commandes en cours (colonnes par mois d'achat, barres par état, tableau des plus anciennes). Segments **synchronisés** sur les 4 pages : Période (`year_number` > `year_month`) et Localisation (`customer_state` > `customer_city`).

**Charte** : thème sombre « E-commerce Brasil » (`Dashboards/Power BI/theme/ecommerce-brasil.json`, copie enregistrée dans le rapport), fond dégradé `bg_bresil.png`, cartes en verre dépoli, titres jaunes, axes et titres de graphiques en blanc (taille 22, sous-titre masqué), KPI avec titre et nom de mesure masqué, filtres de volume de visuel (500 livraisons par mois, 100 par état, 200 par ville, 30 par vendeur). Palette : vert `#2FD063`, jaune `#FFC800`, bleu `#4D8DFF`, orange `#FF7A45`, marine `#002776`.

**Pièges et connaissances utiles**
- Le **pilote ODBC de Power BI exige de l'IPv4**. Sur le partage de connexion iPhone, l'IPv4 ne sortait pas (seul l'IPv6 passait) : changer de réseau a réglé le timeout.
- La carte demande : visuels de carte autorisés (Fichier > Options > Sécurité), **Actualiser** (la colonne `Pays` n'existe qu'après), et `Pays` + `État` + `Ville` en emplacement pour éviter les homonymes (162 noms de villes existent dans plusieurs états). Les noms de rôles du visuel carte (`Category`, `Gradient`, `Tooltips`) sont écrits de mémoire : si besoin, construire la carte une fois à la main, enregistrer, et relire le JSON.
- Formats PBIR validés par Power BI : formes avec `selector: {"id": "default"}` sur `fill` et `outline` (sans lui, la couleur est ignorée), `visualContainerObjects` pour titre et sous-titre, `categoryAxis` et `valueAxis` avec `labelColor` en `ThemeDataColor` `ColorId 0` (blanc), filtre de mesure `Advanced` avec `ComparisonKind: 2` (≥).
- Validation JSON : le schéma `visualContainer/2.14.0` n'est pas publié ; valider contre `2.13.0` en neutralisant la valeur de `$schema`.
- Les scripts de génération utilisés (hors dépôt, dans le dossier temporaire de la session précédente) n'existent plus de façon fiable : si utile, les réécrire dans `scripts/powerbi/`.

## 8. État git à reprendre

- **Non commité** : tout `Dashboards/` mis à jour (rapport, modèle, thème, fond `bg_bresil.png`), plus ce fichier. Contrôler avant de commiter : `git add -n Dashboards`. Doivent rester ignorés : `.pbi/cache.abf`, `.pbi/localSettings.json`, `*.pbix`, `airflow/.env`, `airflow/secrets/`.
- Commit à prévoir, par exemple : « Phase 08 : dashboard Power BI logistique (4 pages, thème sombre, carte) », puis cocher la phase 08 dans `README.md`, ajouter les décisions Power BI à `docs/decisions.md`, et pousser **si je le demande**.

## 9. Reste à faire

1. Valider les 4 pages Power BI (rendu, carte), commiter la phase 08.
2. **Phase 09, Tableau Public** (LOD, pas de DAX) : structure proposée dans `CLAUDE.md` (vue d'ensemble, catégories et produits, paiement et segmentation, statuts et annulations), alimentée par `fact_commandes`, `fact_ventes_categorie`, `dim_produit`, `dim_date`, `dim_client`. À confirmer avec moi avant de commencer. Tableau Public lit un fichier ou un extrait : attention à la licence des données (extrait agrégé, attribution).
3. **Phase 10** : README final (architecture, choix du flux incrémental, remplacement de DataCo), captures d'écran des dashboards avec attribution, vérification que le dépôt ne contient aucune donnée.
4. Nettoyage de fin de projet : arrêter Airflow (`docker compose down`), supprimer la clé du compte de service, vérifier le budget GCP.

## 10. Points ouverts

- « Commandes à risque » (page 4) : avec la date de référence fixe, 99,3 % des commandes en cours dépassent le délai moyen : critère peu discriminant. Alternative à décider (tranches d'ancienneté, ou référence par lot).
- Dégradé de couleur de la carte : à régler dans Power BI (Format > Couleurs > fx) si le rendu par défaut ne convient pas.
- Barres par état : un filtre « N premiers » reste possible si la liste est trop longue.

## 11. Commandes utiles

- dbt (depuis `dbt/`, `.venv` actif) : `dbt run`, `dbt test`, `dbt run --select marts`.
- Airflow (depuis `airflow/`) : `docker compose up -d`, `docker compose down`, interface http://localhost:8080.
- Contrôle BigQuery rapide : `bq query --use_legacy_sql=false --location=us-central1 --project_id=sonorous-lyceum-506109-a5 "<requête>"`. Sous PowerShell, les requêtes multilignes passées en argument sont tronquées : les aplatir sur une ligne.
