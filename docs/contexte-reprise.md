# Contexte de reprise : pipeline e-commerce brésilien

> État au 05/11/2026. Fichier de passation pour une nouvelle session. À lire avec `CLAUDE.md` (règles du projet) avant toute action.
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
| 08 Dashboard Power BI (logistique) | Terminée, commitée et poussée (`a18c327`). 4 pages, thème sombre, carte du Brésil. README : case 08 cochée |
| 09 Dashboard Tableau (ventes) | **Classeur terminé**, commité et poussé (`1431c5e`) : 2 agrégats, 9 tests, script d'export, 6 feuilles et 4 tableaux de bord. **Restent 2 retouches de mise en page et la publication** |
| 10 Documentation et portfolio | **À faire** |

Branche `main` = `origin/main`, arbre propre. Derniers commits : `d1265e5` (agrégats Tableau et dénominateur des taux ventes), `8703f77` (script d'export et attribution), `75c259b` (contexte de reprise), `87ee10b` (classeur Tableau, sources et champs calculés), `8814181` (six feuilles et premier tableau de bord), `1431c5e` (les quatre tableaux de bord).

## 3. Données et licence

- Source : Kaggle `bytadit/ecommerce-order-dataset`, licence **CC BY-NC-SA 4.0** (attribution, non commercial, partage dans les mêmes conditions). Mentionnée dans `README.md`, `docs/decisions.md` et `CLAUDE.md`.
- **Ne jamais publier** : les CSV sources, les `.pbix`, le cache Power BI (`.pbi/cache.abf`), ni aucun export **au grain commande**. Tout cela est dans `.gitignore`.
- **Exception tranchée en phase 09** : les **agrégats** peuvent être exportés et publiés. Tableau Public met son extrait de données en ligne, donc le classeur publié est une adaptation redistribuée, pas une capture : il doit porter l'attribution et la licence (texte prêt à coller dans `docs/attribution-tableau.md`). Deux agrégats seulement, générés par `scripts/export_tableau.py` vers `exports/` (dossier ignoré par git). Détail dans `docs/decisions.md`.
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
- Marts : `shared/` (`dim_client`, `dim_produit`, `dim_date`), `logistique/` (`fact_expeditions`, `fact_commandes_en_cours`), `ventes/` (`fact_commandes`, `fact_ventes_categorie`, `fact_ventes_paiement`).
- Intermédiaires : `models/intermediate/` (`int_taux_retard_vendeur`, `int_taux_retard_etat`), matérialisés en vues. Ils agrègent `fact_expeditions` pour fournir les taux de retard historiques par vendeur et par état. La macro `generate_schema_name` n'ayant pas été touchée, ils atterrissent dans le dataset `staging`.
- Décisions clés (détail dans `docs/decisions.md`) : commande résolue = statut `delivered` **et** date de livraison non nulle ; `reference_date` fixe `2018-09-03` (variable dbt) ; calendrier 2016-01-01 à 2018-12-31 ; `dim_client` et `dim_produit` sans `load_type` ni `load_date` ; `payment_sequential` non repris ; niveau de risque des commandes en cours adossé aux taux de retard historiques (vendeur, état), avec une catégorie `indéterminé` quand aucun signal n'est exploitable, et seuils en variables dbt (`seuil_livraisons_vendeur`, `seuil_taux_retard_vendeur`, `seuil_livraisons_etat`) ; tout taux des marts ventes se calcule sur `nb_orders_statut_connu` et jamais sur `nb_orders`, qui inclut les 38 279 commandes du flux incrémental sans statut ; les agrégats destinés à Tableau ne portent que des mesures additives, et `avg_price` est exclu de l'export pour rendre impossible la moyenne de moyennes.
- Tests : 89 (86 réussis, **3 avertissements attendus** : 6 `delivered` sans date, 4 poids à 0, 3 paiements à 0 mensualité), 0 échec.

## 6. Airflow

- `airflow/` : `Dockerfile` (image Airflow 3.3.2 + venv dbt aux versions de `requirements.txt`), `docker-compose.yaml` (LocalExecutor + PostgreSQL, interface sur `127.0.0.1:8080`, connexion `airflow` / `airflow`), `dbt_profiles/profiles.yml` (compte de service, sans secret), `dags/ecommerce_br_incremental.py`.
- DAG `ecommerce_br_incremental` : `start_date` 2026-10-02, 24 runs quotidiens, `catchup=True`, `max_active_runs=1`. Chaque run : copie du lot mensuel de `source/` vers `raw/`, `dbt run`, `dbt test`, notification. **Les 24 runs sont terminés avec succès.**
- Pour relancer : Docker Desktop doit tourner (il est actuellement arrêté), puis depuis `airflow/` : `docker compose up -d`.
- Fichier local `airflow/.env` (ignoré) : contient le **proxy interne de Docker Desktop** (`HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`), nécessaire parce que les conteneurs n'ont pas d'accès Internet direct sur mon réseau. Modèle : `airflow/.env.example`.
- Dans un terminal PowerShell, `docker` n'est pas toujours dans le PATH : ajoute `C:\Program Files\Docker\Docker\resources\bin`.

## 7. Power BI (phase 08)

Projet au format **PBIP** : `Dashboards/Power BI/logistique.pbip` (fichiers texte : `logistique.Report`, `logistique.SemanticModel`). Le `.pbix` voisin fait doublon et est ignoré par git.

**Modèle** : tables `fact_expeditions`, `fact_commandes_en_cours`, `dim_date` (marquée table de dates), `dim_client` (avec colonne calculée `Pays` = "Brazil", catégories géographiques), `_Mesures`, `int_taux_retard_vendeur` (dimension vendeur, lue depuis le dataset `staging`). Relations : `dim_date` vers `fact_expeditions[delivered_date]` (**active**), `[purchase_date]` et `[estimated_delivery_date]` (**inactives**, via `USERELATIONSHIP`), `dim_date` vers `fact_commandes_en_cours[purchase_date]` (active), `dim_client[customer_id]` vers les deux faits, `int_taux_retard_vendeur[seller_id]` vers les deux faits. Date/heure automatique désactivée. Import (pas DirectQuery), `BillingProject` renseigné.

**Mesures** (`_Mesures`) : Commandes livrées, Taux de retard, Délai moyen (jours), Coût de port moyen, Commandes en cours, Délai moyen par achat, Livrées par achat, Vendeurs actifs, Vendeurs à risque (lit désormais le drapeau dbt `is_vendeur_a_risque` ; plus aucun seuil écrit en DAX ; 40 vendeurs sans segment actif), Ancienneté moyenne (jours), Ancienneté max (jours), Date de référence, Commandes à risque élevé, Commandes à risque modéré, Commandes à risque indéterminé, Part à risque élevé ou modéré.

**Pages** (canevas 1920 × 1080) : Vue d'ensemble, Géographie (carte du Brésil au niveau ville, barres par état, tableau des villes), Vendeurs (nuage, tableau classé par taux de retard), Commandes en cours (KPI « à risque élevé » et « part à risque », colonnes par mois d'achat, barres par état, répartition par niveau de risque, tableau des plus anciennes avec niveau de risque et taux de retard de l'état). Segments **synchronisés** sur les 4 pages : Période (`year_number` > `year_month`) et Localisation (`customer_state` > `customer_city`).

**Charte** : thème sombre « E-commerce Brasil » (`Dashboards/Power BI/theme/ecommerce-brasil.json`, copie enregistrée dans le rapport), fond dégradé `bg_bresil.png`, cartes en verre dépoli, titres jaunes, axes et titres de graphiques en blanc (taille 22, sous-titre masqué), KPI avec titre et nom de mesure masqué, filtres de volume de visuel (500 livraisons par mois, 100 par état, 200 par ville, 30 par vendeur). Palette : vert `#2FD063`, jaune `#FFC800`, bleu `#4D8DFF`, orange `#FF7A45`, marine `#002776`.

**Pièges et connaissances utiles**
- Le **pilote ODBC de Power BI exige de l'IPv4**. Sur le partage de connexion iPhone, l'IPv4 ne sortait pas (seul l'IPv6 passait) : changer de réseau a réglé le timeout.
- La carte demande : visuels de carte autorisés (Fichier > Options > Sécurité), **Actualiser** (la colonne `Pays` n'existe qu'après), et `Pays` + `État` + `Ville` en emplacement pour éviter les homonymes (162 noms de villes existent dans plusieurs états). Les noms de rôles du visuel carte (`Category`, `Gradient`, `Tooltips`) sont écrits de mémoire : si besoin, construire la carte une fois à la main, enregistrer, et relire le JSON.
- Formats PBIR validés par Power BI : formes avec `selector: {"id": "default"}` sur `fill` et `outline` (sans lui, la couleur est ignorée), `visualContainerObjects` pour titre et sous-titre, `categoryAxis` et `valueAxis` avec `labelColor` en `ThemeDataColor` `ColorId 0` (blanc), filtre de mesure `Advanced` avec `ComparisonKind: 2` (≥).
- Validation JSON : le schéma `visualContainer/2.14.0` n'est pas publié ; valider contre `2.13.0` en neutralisant la valeur de `$schema`.
- Les scripts de génération utilisés (hors dépôt, dans le dossier temporaire de la session précédente) n'existent plus de façon fiable : si utile, les réécrire dans `scripts/powerbi/`.

## 8. Tableau (phase 09)

Classeur `Dashboards/Tableau/ventes.twb`, au format **`.twb`** : définition seule, les CSV sont référencés par leur nom. Surtout pas `.twbx`, qui embarquerait les données. Construit dans **Tableau Desktop édition gratuite 2026.2**, et non Tableau Public.

**Sources** : les deux CSV d'`exports/` en sources **distinctes**, jamais jointes ni unionnées — leurs grains diffèrent. Piège rencontré : Tableau a lu `fact_ventes_categorie.csv` en prenant `_` comme séparateur de champs (l'en-tête en compte 14 contre 8 virgules), d'où des champs `F1`, `F2`… Corrigé dans les propriétés du fichier texte, plus l'option « noms de champs dans la première ligne ». La locale du fichier est « français (France) » mais les décimaux à point sont lus correctement.

**Paramètre `Année`** (liste : Toutes / 2016 / 2017 / 2018), **global au classeur**. C'est lui qui permet de piloter deux sources que rien ne relie ; un contrôle sur une seule page suffit à piloter toutes les autres.

**Champs calculés** — dans chaque source : `Filtre période` (`[Année] = "Toutes" OR STR([year_number]) = [Année]`), `Panier moyen` (SUM / SUM), `Taux d'annulation` (sur `nb_orders_statut_connu`). Côté catégorie en plus : `Catégorie affichée` (libellé explicite « Catégorie inconnue »), `Mois` (`MAKEDATE(year_number, month_number, 1)`, sans parse de chaîne donc sans dépendance à la locale), `Part du total` et `Écart au panier global`.

**Les deux pièges LOD**, à ne pas réapprendre :
- `{FIXED : ...}` renvoie la même valeur sur chaque ligne ; il faut l'encadrer d'un `MAX`, sinon un `SUM` la multiplie par le nombre de lignes.
- Un `FIXED` est évalué **avant** les filtres de dimension. Le `Filtre période` est donc passé **en contexte** sur la feuille du panier moyen. Sans cela, sélectionner une année afficherait des parts calculées sur le total des trois ans, sans aucun message d'erreur.

**Feuilles** (6) : Tendance mensuelle, Ventes par catégorie, Ventes hors toys, Panier moyen par catégorie, Paiement par région, Annulations par catégorie.

**Tableaux de bord** (4) : Vue d'ensemble, Catégories et produits, Paiement et segmentation, Statuts et annulations. Attribution CC BY-NC-SA sur les quatre, comme l'impose la clause de partage dans les mêmes conditions.

**Seuil des annulations** : ≥ 500 commandes à statut connu, soit 16 catégories et 92 % des annulations. À 100, le classement était mené par `consoles_games` avec 4 annulations sur 156 — du bruit, pas un taux.

**Constat de données** : `toys` pèse **75 % des commandes et du chiffre d'affaires** (32,8 M sur 43,6 M), vérifié jusqu'à `fact_commandes` joint à `dim_produit`. Le déséquilibre porte sur le volume et non sur le panier : 342,6 pour `toys` contre 341,4 en moyenne générale, quand `garden_tools` atteint 977. D'où la feuille « Ventes hors toys ».

**Reste à faire à la souris** : sur « Paiement et segmentation » et « Statuts et annulations », le bloc d'attribution a été collé en objet flottant et chevauche le haut du graphique ; sur « Catégories et produits », il occupe trop de hauteur. Le déplacement d'un objet flottant est le seul geste que le pilotage à distance n'a pas réussi à produire.

**Astuce** : le copier-coller d'un objet entre tableaux de bord (`Ctrl+C` puis `Ctrl+V`) fonctionne quand le glisser-déposer depuis le volet Objets échoue.

**Incident à connaître** : un collage de texte mal ciblé sur un canevas de tableau de bord crée une **source de données presse-papiers** et corrompt l'état en mémoire (« No such datasource » au rétablissement). Récupération : fermer le classeur en refusant la sauvegarde, puis rouvrir depuis le disque. D'où la règle : enregistrer après chaque étape.

**Limites de l'édition gratuite** : la page d'accueil annonce « Passez à une licence payante pour partager et publier » et indique que l'édition gratuite ne permet pas de partager ou d'exporter des ressources. **À tester avant d'aller plus loin** : menu Serveur > Tableau Public. Si c'est bloqué, installer **Tableau Public Desktop** (produit séparé et gratuit) et y rouvrir le `.twb`, qui est portable. Autre alerte : mise à jour vers 2026.2.1 exigée depuis le 31 août 2026 pour conserver l'édition gratuite, alors que la version installée est 2026.2.

## 9. État git à reprendre

- Tout est commité et poussé. Avant de commiter du Power BI : `git add -n Dashboards` pour contrôler. Doivent rester ignorés : `.pbi/cache.abf`, `.pbi/localSettings.json`, `*.pbix`, `airflow/.env`, `airflow/secrets/`, `exports/`.
- À ajouter plus tard : les décisions Power BI dans `docs/decisions.md` (thème sombre, filtres de volume). Le critère « vendeur à risque » et le niveau de risque des commandes en cours y sont déjà documentés.

## 10. Reste à faire

1. **Phase 09, finition** : repositionner les deux blocs d'attribution flottants (pages « Paiement et segmentation » et « Statuts et annulations »), réduire celui de « Catégories et produits », puis **tester la publication** vers Tableau Public — voir les limites de l'édition gratuite en section 8. Le sélecteur d'année sur les pages 3 et 4 est facultatif, le paramètre étant global au classeur.
2. **Phase 10** : README final (architecture, choix du flux incrémental, remplacement de DataCo), captures d'écran des dashboards avec attribution, vérification que le dépôt ne contient aucune donnée.
3. Nettoyage de fin de projet : arrêter Airflow (`docker compose down`), supprimer la clé du compte de service, vérifier le budget GCP.

## 11. Points ouverts

- **Publication Tableau** : l'édition gratuite de Tableau Desktop annonce ne pas permettre de partager ni d'exporter des ressources. À tester (menu Serveur > Tableau Public) **avant** d'investir dans la finition ; repli éventuel sur Tableau Public Desktop, le `.twb` étant portable.
- Dégradé de couleur de la carte : à régler dans Power BI (Format > Couleurs > fx) si le rendu par défaut ne convient pas.
- Barres par état : un filtre « N premiers » reste possible si la liste est trop longue.

## 12. Commandes utiles

- dbt (depuis `dbt/`, `.venv` actif) : `dbt run`, `dbt test`, `dbt run --select marts`.
- Airflow (depuis `airflow/`) : `docker compose up -d`, `docker compose down`, interface http://localhost:8080.
- Contrôle BigQuery rapide : `bq query --use_legacy_sql=false --location=us-central1 --project_id=sonorous-lyceum-506109-a5 "<requête>"`. Sous PowerShell, les requêtes multilignes passées en argument sont tronquées : les aplatir sur une ligne.
- Pièges `bq` rencontrés : il **ne fonctionne pas sous Git Bash** (il cherche un `python3.13` absent du PATH), donc le lancer depuis PowerShell ; et PowerShell **mange les guillemets doubles** d'une requête passée en argument, ce qui transforme une chaîne SQL en identifiant inconnu — utiliser des guillemets simples doublés (`''canceled''`) à l'intérieur de la chaîne.
- Export Tableau (depuis la racine) : `.venv/Scripts/python.exe scripts/export_tableau.py` — régénère les deux CSV d'`exports/` après un `dbt run`.
