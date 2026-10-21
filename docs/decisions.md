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
