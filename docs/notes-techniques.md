# Notes techniques — pipeline e-commerce brésilien

> Carnet de bord du projet : décisions d'environnement, pièges rencontrés et
> commandes utiles. Les décisions de modélisation sont dans [`decisions.md`](decisions.md).
> Ne contient aucun secret ; la clé GCP n'a jamais été versionnée.

## 1. Données et licence

- Source : Kaggle `bytadit/ecommerce-order-dataset`, licence **CC BY-NC-SA 4.0** (attribution, non commercial, partage dans les mêmes conditions).
- **Ne jamais publier** : les CSV sources, les `.pbix`, le cache Power BI (`.pbi/cache.abf`), ni aucun export **au grain commande**. Tout cela est dans `.gitignore`.
- **Exception tranchée en phase 09** : les **agrégats** peuvent être exportés et publiés. Tableau Public met son extrait de données en ligne, donc un classeur publié est une adaptation redistribuée, pas une capture : il doit porter l'attribution et la licence (texte prêt à coller dans [`attribution-tableau.md`](attribution-tableau.md)). Deux agrégats seulement, générés par `scripts/export_tableau.py` vers `exports/` (dossier ignoré par git).
- Train : 89 316 commandes (backfill). Test : 38 279 commandes (flux incrémental, **sans** statut ni date de livraison — ne jamais en inventer).

## 2. GCP

- Projet `sonorous-lyceum-506109-a5`, région `us-central1`, bucket `e-commerce-brz`.
- Datasets BigQuery : `raw` (5 tables **externes** sur `gs://e-commerce-brz/raw/<table>/*`, partitionnement Hive `load_type`, `load_date`, colonnes en STRING), `staging` (5 vues `stg_*`), `marts` (7 tables).
- Convention GCS : `raw/<table>/load_type=initial|incremental/load_date=AAAA-MM-JJ/<table>.csv`. Lots non livrés dans `source/test/<table>/mois=AAAA-MM/`.
- Compte de service `ecommerce-br-data-pipeline` (Storage Object Admin, BigQuery Data Editor, BigQuery Job User). La règle d'organisation `iam.disableServiceAccountKeyCreation` a été levée le temps de créer la clé, puis rétablie. **La clé a été supprimée en fin de projet**, côté IAM et sur le disque : relancer Airflow suppose d'en créer une nouvelle.
- Volumes finaux : `stg_orders` 127 595 lignes ; `fact_expeditions` 87 422 ; `fact_commandes_en_cours` 38 279 ; `dim_client` 127 595 ; `dim_produit` 32 951 ; `dim_date` 1 096.

## 3. dbt

- dbt **Core 1.12.6** + `dbt-bigquery 1.12.1`, versions figées dans `requirements.txt`, dans le `.venv` à la racine.
- Piège : un **dbt global (Fusion 2.x)** est installé dans `C:\Users\Nasra\.local\bin`. Toujours activer le `.venv` (`.venv\Scripts\Activate.ps1`) et lancer dbt **depuis le dossier `dbt/`**. L'extension VS Code est réglée sur le dbt du `.venv`.
- Profil dev : `C:\Users\Nasra\.dbt\profiles.yml` (oauth, dataset `staging`, `location: us-central1`). Hors dépôt.
- Macro `generate_schema_name` : les modèles `marts` vont dans `marts`, le reste dans `staging`.
- Marts : `shared/` (`dim_client`, `dim_produit`, `dim_date`), `logistique/` (`fact_expeditions`, `fact_commandes_en_cours`), `ventes/` (`fact_commandes`, `fact_ventes_categorie`, `fact_ventes_paiement`).
- Intermédiaires : `models/intermediate/` (`int_taux_retard_vendeur`, `int_taux_retard_etat`), matérialisés en vues. Ils agrègent `fact_expeditions` pour fournir les taux de retard historiques par vendeur et par état. La macro `generate_schema_name` n'ayant pas été touchée, ils atterrissent dans le dataset `staging`.
- Décisions clés (détail dans [`decisions.md`](decisions.md)) : commande résolue = statut `delivered` **et** date de livraison non nulle ; `reference_date` fixe `2018-09-03` (variable dbt) ; calendrier 2016-01-01 à 2018-12-31 ; `dim_client` et `dim_produit` sans `load_type` ni `load_date` ; `payment_sequential` non repris ; niveau de risque des commandes en cours adossé aux taux de retard historiques (vendeur, état), avec une catégorie `indéterminé` quand aucun signal n'est exploitable, et seuils en variables dbt ; tout taux des marts ventes se calcule sur `nb_orders_statut_connu` et jamais sur `nb_orders`, qui inclut les 38 279 commandes du flux incrémental sans statut ; les agrégats destinés à Tableau ne portent que des mesures additives, et `avg_price` est exclu de l'export pour rendre impossible la moyenne de moyennes.
- Tests : 89 (86 réussis, **3 avertissements attendus** : 6 `delivered` sans date, 4 poids à 0, 3 paiements à 0 mensualité), 0 échec.

## 4. Airflow

- `airflow/` : `Dockerfile` (image Airflow 3.3.2 + venv dbt aux versions de `requirements.txt`), `docker-compose.yaml` (LocalExecutor + PostgreSQL, interface sur `127.0.0.1:8080`), `dbt_profiles/profiles.yml`, `dags/ecommerce_br_incremental.py`.
- DAG `ecommerce_br_incremental` : `start_date` 2026-10-02, 24 runs quotidiens, `catchup=True`, `max_active_runs=1`. Chaque run : copie du lot mensuel de `source/` vers `raw/`, `dbt run`, `dbt test`, notification. **Les 24 runs se sont terminés avec succès.**
- Pour relancer : Docker Desktop doit tourner, puis depuis `airflow/` : `docker compose up -d`.
- Fichier local `airflow/.env` (ignoré) : contient le **proxy interne de Docker Desktop** (`HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`), nécessaire parce que les conteneurs n'ont pas d'accès Internet direct sur ce réseau. Modèle : `airflow/.env.example`.
- Dans un terminal PowerShell, `docker` n'est pas toujours dans le PATH : ajouter `C:\Program Files\Docker\Docker\resources\bin`.

## 5. Power BI

Projet au format **PBIP** : `Dashboards/Power BI/logistique.pbip` (fichiers texte : `logistique.Report`, `logistique.SemanticModel`). Le `.pbix` voisin fait doublon et est ignoré par git.

**Modèle** : tables `fact_expeditions`, `fact_commandes_en_cours`, `dim_date` (marquée table de dates), `dim_client` (colonne calculée `Pays` = « Brazil », catégories géographiques), `_Mesures`, `int_taux_retard_vendeur` (dimension vendeur, lue depuis le dataset `staging`). Relations : `dim_date` vers `fact_expeditions[delivered_date]` (**active**), `[purchase_date]` et `[estimated_delivery_date]` (**inactives**, via `USERELATIONSHIP`), `dim_date` vers `fact_commandes_en_cours[purchase_date]` (active), `dim_client[customer_id]` vers les deux faits, `int_taux_retard_vendeur[seller_id]` vers les deux faits. Date/heure automatique désactivée. Import (pas DirectQuery).

**Pages** (canevas 1920 × 1080) : Vue d'ensemble, Géographie (carte du Brésil au niveau ville, barres par état, tableau des villes), Vendeurs (nuage, tableau classé par taux de retard), Commandes en cours. Segments **synchronisés** sur les 4 pages : Période (`year_number` > `year_month`) et Localisation (`customer_state` > `customer_city`).

**Charte** : thème sombre « E-commerce Brasil » (`Dashboards/Power BI/theme/ecommerce-brasil.json`), fond dégradé `bg_bresil.png`, cartes en verre dépoli, titres jaunes, filtres de volume de visuel (500 livraisons par mois, 100 par état, 200 par ville, 30 par vendeur). Palette : vert `#2FD063`, jaune `#FFC800`, bleu `#4D8DFF`, orange `#FF7A45`, marine `#002776`.

**Pièges et connaissances utiles**

- **Power BI Desktop réécrit les fichiers du projet à la simple ouverture** (formats de mesure, cadrage de carte). Le fermer avant toute modification manuelle des fichiers PBIP, et relire le diff avant de commiter.
- Le **pilote ODBC de Power BI exige de l'IPv4**. Sur un partage de connexion iPhone, l'IPv4 ne sortait pas (seul l'IPv6 passait) : changer de réseau a réglé le timeout.
- La carte demande : visuels de carte autorisés (Fichier > Options > Sécurité), **Actualiser** (la colonne `Pays` n'existe qu'après), et `Pays` + `État` + `Ville` en emplacement pour éviter les homonymes — 162 noms de villes existent dans plusieurs états.
- Formats PBIR validés : formes avec `selector: {"id": "default"}` sur `fill` et `outline` (sans lui, la couleur est ignorée), `visualContainerObjects` pour titre et sous-titre, `categoryAxis` et `valueAxis` avec `labelColor` en `ThemeDataColor` `ColorId 0`, filtre de mesure `Advanced` avec `ComparisonKind: 2` (≥).
- Validation JSON : le schéma `visualContainer/2.14.0` n'est pas publié ; valider contre `2.13.0` en neutralisant la valeur de `$schema`.
- Export des pages en image : **Fichier > Exporter au format PDF**, puis `pdftoppm -png -scale-to-x 1600`. Une capture d'écran incruste le filigrane d'activation Windows.

## 6. Tableau

Classeur `Dashboards/Tableau/ventes.twb`, au format **`.twb`** : définition seule, les CSV sont référencés par leur nom. Surtout pas `.twbx`, qui embarquerait les données. Construit dans **Tableau Desktop édition gratuite 2026.2**.

**Sources** : les deux CSV d'`exports/` en sources **distinctes**, jamais jointes ni unionnées — leurs grains diffèrent. Piège rencontré : Tableau a lu `fact_ventes_categorie.csv` en prenant `_` comme séparateur de champs (l'en-tête en compte 14 contre 8 virgules), d'où des champs `F1`, `F2`… Corrigé dans les propriétés du fichier texte, plus l'option « noms de champs dans la première ligne ».

**Paramètre `Année`** (Toutes / 2016 / 2017 / 2018), **global au classeur**. C'est lui qui permet de piloter deux sources que rien ne relie ; un contrôle sur une seule page suffit.

**Champs calculés** — dans chaque source : `Filtre période`, `Panier moyen` (SUM / SUM), `Taux d'annulation` (sur `nb_orders_statut_connu`). Côté catégorie en plus : `Catégorie`, `Mois` (`MAKEDATE(year_number, month_number, 1)`, sans parse de chaîne donc sans dépendance à la locale), `Part du total` et `Écart au panier global`.

**Les deux pièges LOD**, à ne pas réapprendre :

- `{FIXED : ...}` renvoie la même valeur sur chaque ligne ; il faut l'encadrer d'un `MAX`, sinon un `SUM` la multiplie par le nombre de lignes.
- Un `FIXED` est évalué **avant** les filtres de dimension. Le `Filtre période` est donc passé **en contexte** sur la feuille du panier moyen ; le filtre `Catégorie`, lui, reste hors contexte. Sans cela, l'écart au panier global tomberait à zéro dès qu'une catégorie est sélectionnée, sans aucun message d'erreur.

**Seuil des annulations** : ≥ 500 commandes à statut connu, soit 16 catégories et 92 % des annulations. À 100, le classement était mené par `consoles_games` avec 4 annulations sur 156 — du bruit, pas un taux.

**Constat de données** : `toys` pèse **75 % des commandes et du chiffre d'affaires** (32,8 M sur 43,6 M), vérifié jusqu'à `fact_commandes` joint à `dim_produit`. Le déséquilibre porte sur le volume et non sur le panier : 342,6 pour `toys` contre 341,4 en moyenne générale, quand `garden_tools` atteint 977. D'où la feuille « Ventes hors toys ».

**Refonte des quatre pages (17/11/2026)** : reconstruites **en éditant le XML du `.twb`**, pas à la souris. 1600 × 900, bandeau titre, rangée de cartes KPI, colonne de filtres à droite, pied d'attribution, charte du thème Power BI. Quatre scripts de chantier, non versionnés, reconstruisent le classeur depuis une copie d'origine : filtres des feuilles, pages, styles, formats des mesures.

**Les règles du XML Tableau apprises à cette occasion**, toutes vérifiées, aucune n'est devinable :

- `layout-flow` **ignore les largeurs et hauteurs écrites** et redistribue l'espace selon le contenu, sauf si l'enfant porte `is-fixed='true'`. `layout-basic` respecte les coordonnées absolues. Une rangée de KPI ou une pile de page doit donc être en `layout-basic`.
- Une feuille ne remplit sa zone que si son **viewpoint** porte `<zoom type='entire-view' />`, dans `<window class='dashboard'>`. Sans lui, elle garde sa taille naturelle, collée en haut à gauche.
- Les couleurs de fond d'une zone vivent dans son `<zone-style>`, à côté de `border-color` et `margin` — pas dans une règle `dash-container` au niveau du tableau de bord.
- Une feuille référencée par un tableau de bord **doit figurer dans les `<viewpoints>`** de sa fenêtre, sinon Tableau refuse le fichier avec le code `2B05CF18`.
- Dans un `<view>`, l'ordre des éléments est imposé : `datasource-dependencies*`, puis `filter*`, puis les tris, puis `slices`, puis `aggregation`. Un filtre placé après un tri fait échouer le chargement — mais le message d'erreur donne littéralement la grammaire attendue, ce qui en fait un diagnostic rapide.
- Un titre personnalisé se pose en `<layout-options><title>` juste après l'ouverture du `<worksheet>`.
- **La taille du chiffre d'une carte KPI n'est pas une police.** C'est le curseur « Taille » de la fiche Repères : `<mark-sizing mark-sizing-setting='marks-scaling-off' />` frère de `<mark>`, et `<format attr='size' value='…' />` dans la règle de repère du volet. Une règle `element='label'` avec `font-size` n'a aucun effet sur le texte d'un repère.
- Le format d'une mesure se déclare en `default-format` sur sa colonne. Tableau l'applique à un **champ calculé**, mais **pas à une colonne physique agrégée** comme `SUM(total_price)` — là il faut une règle `<style-rule element='cell'>` explicite. Attention : cette règle **écrase** le `default-format`, donc les deux doivent dire la même chose.
- Renommer la légende d'un champ corrige les en-têtes et les légendes de couleur, mais **pas les axes** : un axe garde le nom du champ, et pour une date tronquée il compose « Mois de Mois ». Il faut un titre explicite, `<format attr='title' field='…' scope='cols'>`.

**Deux méthodes qui font gagner du temps** : le classeur d'exemple `Superstore.twbx` livré avec Tableau (`help/Workbooks/`) contient des exemples valides de presque toutes ces balises — le dézipper et y chercher la syntaxe plutôt que la deviner. Et le fichier de verrou `~<nom>__<pid>.twbr` est du **XML lisible** : il contient l'état en mémoire, donc un réglage fait à la souris et pas encore enregistré. C'est le moyen le plus sûr d'apprendre ce que Tableau écrit pour un réglage donné.

**Incident à connaître** : un collage de texte mal ciblé sur un canevas de tableau de bord crée une **source de données presse-papiers** et corrompt l'état en mémoire (« No such datasource » au rétablissement). Récupération : fermer le classeur en refusant la sauvegarde, puis rouvrir depuis le disque. D'où la règle : enregistrer après chaque étape.

**Export des pages en image** : Tableau de bord > Exporter une image, qui sort le canevas en 1600 × 900 sans menus ni volets.

**Limites de l'édition gratuite** : les entrées « Enregistrer dans Tableau Public » du menu Serveur sont **désactivées** — vérifié en cliquant dessus. Le classeur n'est donc pas publié en ligne ; le `.twb` étant portable, il s'ouvre dans **Tableau Public Desktop** (produit séparé et gratuit) pour qui veut le rejouer. Autre alerte : une mise à jour vers 2026.2.1 est exigée depuis le 31 août 2026 pour conserver l'édition gratuite, alors que la version installée est 2026.2.

## 7. Versionnement

- Avant de commiter du Power BI : `git add -n Dashboards` pour contrôler. Doivent rester ignorés : `.pbi/cache.abf`, `.pbi/localSettings.json`, `*.pbix`, `airflow/.env`, `airflow/secrets/`, `exports/`, `*.twbx`, `*.twbr`.
- Contrôle régulier : `git ls-files` ne doit remonter aucun secret ni aucune donnée.

## 8. Points ouverts

- **Devise des montants** : `R$` est une hypothèse tirée de l'origine brésilienne du jeu de données, pas une information déclarée par la source. Voir [`decisions.md`](decisions.md).
- Les décisions **Power BI** page par page (filtres de volume, cadrage de la carte) ne sont pas encore consignées dans [`decisions.md`](decisions.md) ; le thème sombre y figure via la section sur la charte partagée.
- Dégradé de couleur de la carte : à régler dans Power BI (Format > Couleurs > fx) si le rendu par défaut ne convient pas.

## 9. Commandes utiles

- dbt (depuis `dbt/`, `.venv` actif) : `dbt run`, `dbt test`, `dbt run --select marts`.
- Airflow (depuis `airflow/`) : `docker compose up -d`, `docker compose down`, interface http://localhost:8080.
- Contrôle BigQuery rapide : `bq query --use_legacy_sql=false --location=us-central1 --project_id=sonorous-lyceum-506109-a5 "<requête>"`.
- Pièges `bq` : il **ne fonctionne pas sous Git Bash** (il cherche un `python3.13` absent du PATH), donc le lancer depuis PowerShell ; et PowerShell **mange les guillemets doubles** d'une requête passée en argument, ce qui transforme une chaîne SQL en identifiant inconnu — utiliser des guillemets simples doublés (`''canceled''`) à l'intérieur de la chaîne. Les requêtes multilignes passées en argument sont tronquées : les aplatir sur une ligne.
- Export Tableau (depuis la racine) : `.venv/Scripts/python.exe scripts/export_tableau.py` — régénère les deux CSV d'`exports/` après un `dbt run`.
