# Décisions de conception

Une entrée par décision : contexte, décision, raison.

## Convention de stockage GCS (format Hive)
- **Contexte :** les fichiers doivent être lisibles par BigQuery avec des colonnes de partition.
- **Décision :** `raw/<table>/load_type=initial|incremental/load_date=AAAA-MM-JJ/<table>.csv` ; lots non livrés dans `source/test/<table>/mois=AAAA-MM/<table>.csv`. L'information de lot est portée par le chemin, jamais par le nom de fichier.
- **Raison :** `raw/` ne contient que ce qui a été livré ; `source/` joue le rôle du système source non encore migré.

## `load_date` = date de dépôt technique
- **Contexte :** deux dates coexistent, la date métier de la commande et la date de livraison du lot.
- **Décision :** `load_date` est la date de dépôt, alignée sur `{{ ds }}` d'Airflow.
- **Raison :** rejouer un run redonne le même chemin ; la date métier reste dans les données.

## Couche `raw` entièrement en STRING
- **Contexte :** les CSV contiennent des vides et des formats hétérogènes.
- **Décision :** toutes les colonnes de données sont en STRING ; `load_type` est STRING et `load_date` DATE (déduites du chemin).
- **Raison :** `raw` reste fidèle à la source ; le typage et les erreurs de conversion se traitent dans le staging dbt.

## Tables `raw` externes plutôt que natives
- **Contexte :** les tables natives ne voient pas les nouveaux fichiers déposés dans GCS.
- **Décision :** les 5 tables `raw` sont des tables externes sur `gs://e-commerce-brz/raw/<table>/*`, partitionnement Hive, 1 ligne d'en-tête ignorée.
- **Raison :** idempotence par construction (un retry réécrit le même fichier, pas de doublon). Écartées : tables natives partitionnées (trop long pour l'échéance) et suppression puis ajout (deux opérations non atomiques).

## Lecture des CSV par position
- **Contexte :** orders du test n'a que 4 colonnes contre 7 pour le train, `order_status` étant en 3ᵉ position.
- **Décision :** les lots orders du test sont écrits au format du train (7 colonnes, mêmes positions), colonnes absentes laissées vides.
- **Raison :** BigQuery lit les CSV par position ; sans alignement, les valeurs seraient décalées dans les mauvaises colonnes.

## 24 lots, un par mois calendaire
- **Contexte :** le test couvre 2016-10-03 → 2018-09-03, comme le train, sans chevauchement d'`order_id` ni de `customer_id`.
- **Décision :** un lot par mois d'achat (2016-10 → 2018-09), dates d'origine conservées. Un mois vide (2016-11) donne un CSV avec l'en-tête seul.
- **Raison :** granularité la plus proche d'un usage réel ; la livraison d'un mois vide reste tracée dans GCS.

## Rattachement des tables au lot
- **Contexte :** seule orders porte la date d'achat.
- **Décision :** orders par mois de `order_purchase_timestamp` ; order_items et payments par mois de la commande (`order_id`) ; customers par mois de la commande (`customer_id`) ; products suit ses order_items, doublons exacts conservés (dédoublonnés par `product_id` en staging dbt).
- **Raison :** chaque lot est cohérent (0 orphelin, même nombre de lignes dans les 5 tables) ; la conservation des lignes est contrôlée par le script.

## Aucune valeur inventée pour le test
- **Contexte :** le test n'a ni `order_status`, ni dates de livraison réelle ou estimée.
- **Décision :** ces colonnes restent vides ; le staging dbt dérive un statut « en cours / issue inconnue ». Les KPIs de délai se calculent sur les commandes à issue connue.
- **Raison :** un délai moyen incluant des commandes non résolues serait faussé silencieusement.

## Date de référence fixe pour le risque
- **Contexte :** l'indicateur de commande à risque compare à une date.
- **Décision :** date fixe 2018-09-03, pas `CURRENT_DATE`.
- **Raison :** le résultat doit être reproductible et cohérent avec les dates d'origine conservées.

## Orchestration : un mois par run, calculé depuis `ds`
- **Contexte :** DAG quotidien, 24 lots (la mise en œuvre est en phase 07).
- **Décision :** mois livré calculé à partir de `ds` et du `start_date` (jours écoulés), sans compteur ni comptage de dossiers ; `catchup=True` ; `end_date` = `start_date` + 23 jours. Chaque run copie le lot de `source/` vers `raw/`, puis `dbt run`, puis `dbt test`.
- **Raison :** un retry ou un clear redonne le même mois ; un jour d'arrêt du PC ne crée pas de trou. Le choix du `start_date` (aujourd'hui ou passé) reste à trancher.

## Staging : fidèle à la source, une ligne par entité
- **Contexte :** `raw` contient le train et les lots du test, avec des doublons exacts dans `products` et des zéros initiaux perdus dans les codes postaux.
- **Décision :** 5 vues `stg_*`, sans jointure ; `nullif` avant `cast` (le vide devient `NULL`, une valeur corrompue fait échouer le modèle) ; montants en `NUMERIC` ; préfixes postaux remis sur 5 caractères avec `lpad` ; `stg_products` dédoublonné par `product_id` ; `is_outcome_unknown` dérivé dans `stg_orders` sans inventer de statut.
- **Raison :** le staging nettoie le bruit sans corriger le métier ; les valeurs suspectes (poids à 0, livraison sans date) sont laissées visibles pour les tests de la phase 06.

## Datasets et macro `generate_schema_name`
- **Contexte :** par défaut dbt concatène le dataset du profil et le dataset personnalisé (`staging_marts`).
- **Décision :** macro `generate_schema_name` surchargée ; staging dans `staging` (dataset du profil), marts dans `marts` via `+schema: marts`.
- **Raison :** un dataset par couche (raw, staging, marts), et un accès des dashboards limité à `marts`.

## Commande résolue
- **Contexte :** 87 428 commandes `delivered` dans le train, mais 6 sans date de livraison.
- **Décision :** résolue = statut `delivered` ET date de livraison non nulle (87 422 commandes dans `fact_expeditions`). Les commandes sans statut (flux incrémental) vont dans `fact_commandes_en_cours`, jamais mélangées aux délais.
- **Raison :** un délai sans date de livraison fausserait silencieusement les moyennes. Les 6 `delivered` sans date seront signalées par un test `warn` sur `stg_orders` (phase 06).

## `dim_date` : années civiles 2016 à 2018
- **Contexte :** les dates vont du 2016-09-04 (achat) au 2018-10-25 (livraison estimée).
- **Décision :** calendrier du 2016-01-01 au 2018-12-31 (1 096 jours), généré avec `GENERATE_DATE_ARRAY`.
- **Raison :** il doit couvrir toutes les dates jointes par les faits, pas seulement les dates d'achat.

## Grain des marts
- **Contexte :** dans ce jeu de données, une commande a un article et un paiement.
- **Décision :** `fact_commandes`, `fact_expeditions` et `fact_commandes_en_cours` ont une ligne par commande ; `fact_ventes_categorie` une ligne par catégorie et par mois d'achat ; `dim_client` et `dim_produit` n'ont ni `load_type` ni `load_date`. `payment_sequential` n'est pas repris dans `fact_commandes`.
- **Raison :** les clés sont uniques (vérifié) et les métadonnées de chargement ne sont pas des attributs métier.

## Date de référence fixe
- **Contexte :** l'ancienneté d'une commande en cours ne doit pas dépendre de la date d'exécution.
- **Décision :** variable dbt `reference_date: '2018-09-03'` dans `dbt_project.yml`, utilisée par `fact_commandes_en_cours` (`days_since_purchase`).
- **Raison :** résultats reproductibles. Les lots du test s'étalent sur deux ans, donc avec une date fixe toutes les commandes en cours paraissent anciennes (693 à 700 jours pour le lot 2016-10). Point tranché depuis : la date de référence est conservée telle quelle et l'ancienneté reste un indicateur descriptif, mais elle n'est plus utilisée comme critère de risque (voir « Commandes en cours : niveau de risque adossé à l'historique »).

## Tests et qualité : génériques, singuliers, sévérité
- **Contexte :** `accepted_range` n'existe pas dans dbt de base (il vient de `dbt_utils`) ; la source contient des anomalies connues (6 `delivered` sans date, 4 poids à 0, 3 paiements à 0 mensualité).
- **Décision :** pas de package. Tests génériques (`unique`, `not_null`, `accepted_values`, `relationships`) dans `_staging.yml` et `_marts.yml` ; règles métier et plages de valeurs en tests singuliers dans `dbt/tests/`. Les anomalies connues de la source sont en `severity: warn`, les violations de règles métier en `error`.
- **Raison :** un test qui échoue doit signaler un bug ou une régression ; une anomalie déjà identifiée dans la source est signalée sans bloquer `dbt build` ni le futur DAG Airflow. Le test sur les `delivered` sans date porte sur `stg_orders` : `fact_expeditions` les exclut déjà.

## Airflow : LocalExecutor, dbt dans son propre venv
- **Contexte :** Airflow tourne dans un conteneur Linux, avec ses propres dépendances ; Cloud Composer est exclu (payant).
- **Décision :** Docker Compose en LocalExecutor + PostgreSQL (pas de Redis ni de worker Celery) ; image Airflow 3.3.2 étendue avec un venv dbt installé depuis `requirements.txt` ; `dbt run` et `dbt test` lancés par des `BashOperator`. Le profil dbt du conteneur (`airflow/dbt_profiles/profiles.yml`) utilise `method: service-account` et ne contient aucun secret.
- **Raison :** mêmes versions de dbt en local et dans Airflow, sans conflit de dépendances, et une empreinte mémoire réduite pour une machine personnelle.

## DAG : un lot par run, calculé depuis la date logique
- **Contexte :** 24 lots mensuels à livrer, avec une publication proche.
- **Décision :** `start_date` fixé au 2026-10-02 (pas de date relative), `end_date` = `start_date` + 23 jours, `catchup=True`, `max_active_runs=1` : les 24 runs se rattrapent d'un coup, un à la fois. Le mois livré se déduit de la date logique, la copie GCS écrase la même destination à chaque tentative, et le DAG est créé en pause.
- **Raison :** idempotence (retry ou clear sans doublon), résultats reproductibles, et rien ne s'exécute vers GCS et BigQuery avant l'activation volontaire. Le test `unique` sur `order_id` interdit aussi de laisser une copie manuelle du même lot sous un autre `load_date`.

## Identifiants GCP du conteneur et réseau Docker
- **Contexte :** un conteneur n'a pas accès au `gcloud` local. Sur la machine de développement, ses connexions directes à Internet expirent et seul le proxy interne de Docker Desktop passe.
- **Décision :** clé JSON du compte de service montée en lecture seule depuis `airflow/secrets/` (ignoré par git, jamais copiée dans l'image) ; la règle d'organisation `iam.disableServiceAccountKeyCreation` n'est levée que le temps de créer la clé, puis rétablie ; une clé orpheline créée par erreur a été supprimée. Le proxy est optionnel (variables `HTTP_PROXY`, `HTTPS_PROXY` et `NO_PROXY` dans `airflow/.env`, jamais commité).
- **Raison :** moindre privilège (rôles du compte limités au stockage et à BigQuery), aucun secret dans le dépôt, et un compose qui reste portable.

## Source des données et licence (CC BY-NC-SA 4.0)
- **Contexte :** le jeu de données vient de Kaggle (`bytadit/ecommerce-order-dataset`), sous licence CC BY-NC-SA 4.0 : attribution obligatoire, usage non commercial, partage des adaptations dans les mêmes conditions.
- **Décision :** aucune donnée n'est redistribuée par le dépôt (CSV et fichiers `.pbix` ignorés par git) ; la source, l'auteur et la licence sont cités dans le README, avec la mention que les données ont été modifiées. Pour le portfolio : code et captures d'écran avec attribution, pas d'export de données.
- **Raison :** un `.pbix` en mode Import ou un export des marts serait une adaptation des données, qu'il faudrait republier sous la même licence ; le code, lui, est propre au projet.

## Commandes en cours : niveau de risque adossé à l'historique
- **Contexte :** la page « Commandes en cours » du dashboard devait signaler les commandes à risque. Le premier critère envisagé comparait l'ancienneté de la commande au délai de livraison moyen, et classait 99,3 % du flux à risque. Le diagnostic a montré que ce n'était pas un problème de seuil : chaque lot incrémental couvre un mois calendaire d'achats, donc avec une date de référence fixe l'ancienneté est une fonction du mois d'achat (693 à 700 jours pour le lot 2016-10, 5 à 33 jours pour 2018-08) et ne contient aucune information de risque. Une référence propre à chaque lot bornerait l'ancienneté à 0-30 jours, mais elle mesurerait alors surtout le jour du mois de l'achat : le même artefact, mieux déguisé.
- **Décision :** le risque est calculé à partir des seuls signaux connus sur une commande sans issue, qualifiés par des taux déjà mesurés sur le backfill. Deux modèles intermédiaires (`int_taux_retard_vendeur`, `int_taux_retard_etat`) agrègent `fact_expeditions` ; `fact_commandes_en_cours` les reporte en colonnes et en déduit `niveau_risque` : `élevé` si les deux signaux se cumulent, `modéré` si un seul, `indéterminé` si le vendeur n'atteint pas le volume minimal et que l'état n'est pas à risque, `faible` sinon. Un `niveau_risque_ordre` (1 à 4) existe pour le tri dans les dashboards. Seuils en variables dbt : `seuil_livraisons_vendeur: 30`, `seuil_taux_retard_vendeur: 0.15`, `seuil_livraisons_etat: 200` ; le taux national n'est jamais codé en dur, il est recalculé à chaque exécution. Répartition obtenue : 362 `élevé` (0,95 %), 11 870 `modéré` (31,0 %), 21 016 `faible` (54,9 %), 5 031 `indéterminé` (13,1 %).
- **Raison :** le niveau de risque n'est pas un pronostic de livraison, c'est le report d'un taux de retard observé — aucun délai n'est recalculé sur les commandes en cours et aucun statut n'est inventé. La catégorie `indéterminé` est indispensable : 282 commandes ont un vendeur absent de l'historique et 6 885 un vendeur à moins de 30 livraisons, soit 19 % du flux sur lequel le taux vendeur est inexistant ou fragile ; les ranger en « non à risque » affirmerait une absence de risque faute d'information. Un signal positif connu prime cependant sur une information manquante, donc 2 136 de ces commandes passent en `modéré` par leur état plutôt qu'en `indéterminé`. Les modèles lisent `fact_expeditions` plutôt que le staging : la dépendance entre marts est déjà le motif du projet (`fact_ventes_categorie` lit `fact_commandes`), et cela évite de dupliquer les définitions de « commande résolue » et de `is_late`. Les deux vues intermédiaires atterrissent dans le dataset `staging`, conséquence assumée de la macro `generate_schema_name`, qui n'a pas été modifiée.
- **Conséquence Power BI :** les deux taux, les trois drapeaux, `niveau_risque` et `niveau_risque_ordre` (masqué, utilisé en `sortByColumn`) sont déclarés dans `fact_commandes_en_cours` ; `int_taux_retard_vendeur` est ajouté au modèle comme dimension vendeur, relié à `fact_expeditions[seller_id]` et `fact_commandes_en_cours[seller_id]`. La mesure `Vendeurs à risque` ne réécrit plus les seuils en DAX, elle lit le drapeau dbt : `CALCULATE ( DISTINCTCOUNT ( fact_expeditions[seller_id] ), int_taux_retard_vendeur[is_vendeur_a_risque] = TRUE () )`. Le sens change et c'est voulu : la classification devient globale et stable au lieu d'être recalculée dans le contexte de filtre, où une sélection d'un seul mois ne pouvait presque jamais atteindre les 30 livraisons et faisait tomber le KPI à zéro. La mesure reste sensible aux segments par la population comptée, pas par le classement. Vérifié : 40 vendeurs à risque sans segment, comme avec l'ancienne formule.
