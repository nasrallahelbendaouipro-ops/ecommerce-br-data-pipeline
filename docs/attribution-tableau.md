# Attribution du classeur Tableau Public

> Phase 09. À appliquer **avant** de publier le classeur, pas après : sur Tableau Public,
> enregistrer équivaut à publier.

## Pourquoi c'est obligatoire

Les données viennent de Kaggle sous licence **CC BY-NC-SA 4.0**. Trois obligations en découlent,
et Tableau Public les déclenche toutes les trois parce qu'il met l'extrait de données en ligne :
le classeur publié est une **adaptation redistribuée**, pas une simple capture.

- **BY** — citer la source, l'auteur et la licence, et signaler que les données ont été modifiées.
- **NC** — usage non commercial. Un classeur de portfolio en fait partie, mais il ne doit pas
  servir de support à une offre payante.
- **SA** — l'adaptation doit être partagée sous la même licence. Le classeur publié est donc
  lui-même sous CC BY-NC-SA 4.0, et doit le dire.

Seuls des agrégats sont exportés (voir `scripts/export_tableau.py`), ce qui limite la portée de la
redistribution mais ne supprime aucune des trois obligations.

## Texte à coller

À placer dans un objet texte visible sur **chaque** tableau de bord du classeur, et à reprendre
dans le champ de description du classeur sur Tableau Public.

```
Source : « Ecommerce Order & Supply Chain Dataset » par bytadit (Kaggle),
sous licence CC BY-NC-SA 4.0 — creativecommons.org/licenses/by-nc-sa/4.0/
Données modifiées : chargées dans BigQuery, nettoyées et modélisées avec dbt,
puis agrégées (aucune donnée au grain commande n'est publiée).
Ce classeur est partagé sous la même licence, pour un usage non commercial.
```

## Ce qui ne doit pas être publié

- Les CSV sources et les lots mensuels du flux incrémental.
- Un extrait au grain commande, quelle qu'en soit la forme.
- Les fichiers de `exports/` ne sont pas versionnés (voir `.gitignore`) : ils servent uniquement
  d'entrée locale à Tableau.

## Pièges de calcul à ne pas oublier

- Les taux se calculent sur `nb_orders_statut_connu`, jamais sur `nb_orders` : ce dernier inclut
  les 38 279 commandes du flux incrémental, dont l'issue est inconnue.
- `avg_price` n'est pas exporté volontairement. Le panier moyen s'obtient par
  `SUM([Total Price]) / SUM([Nb Orders])`, y compris dans les LOD.
