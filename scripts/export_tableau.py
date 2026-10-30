"""Exporte les agrégats du mart ventes en CSV pour Tableau Public.

Règles (phase 09) :
- seuls les agrégats quittent BigQuery ; aucune ligne au grain commande n'est exportée,
  la licence CC BY-NC-SA interdisant de redistribuer les données source
- les agrégats ne portent que des mesures additives (compteurs et sommes) : Tableau
  recalcule les moyennes en SUM / SUM et les LOD restent exactes
- avg_price est écarté de l'export : une moyenne déjà agrégée utilisée dans une LOD
  donnerait une moyenne de moyennes. Le panier moyen se calcule avec total_price et
  nb_orders
- les taux se calculent sur nb_orders_statut_connu, jamais sur nb_orders, qui inclut
  le flux incrémental sans statut
- sortie en UTF-8 sans BOM

Sortie : exports/<table>.csv (dossier ignoré par git)
Usage  : .venv/Scripts/python.exe scripts/export_tableau.py
"""
import csv

from google.cloud import bigquery
from pathlib import Path

PROJET = "sonorous-lyceum-506109-a5"
LOCALISATION = "us-central1"
SORTIE = Path(__file__).resolve().parent.parent / "exports"

# Moyennes pré-calculées : inutilisables en LOD, donc jamais exportées.
EXCLUES = {"avg_price"}

TABLES = ["fact_ventes_categorie", "fact_ventes_paiement"]


def exporter(client, table):
    reference = f"{PROJET}.marts.{table}"
    colonnes = [c.name for c in client.get_table(reference).schema if c.name not in EXCLUES]
    resultat = client.query(
        f"select {', '.join(colonnes)} from `{reference}`", location=LOCALISATION
    ).result()

    chemin = SORTIE / f"{table}.csv"
    lignes = 0
    with open(chemin, "w", newline="", encoding="utf-8") as fichier:
        ecrivain = csv.writer(fichier)
        ecrivain.writerow(colonnes)
        for ligne in resultat:
            ecrivain.writerow(list(ligne.values()))
            lignes += 1

    return chemin, lignes, colonnes


def main():
    SORTIE.mkdir(exist_ok=True)
    client = bigquery.Client(project=PROJET)
    for table in TABLES:
        chemin, lignes, colonnes = exporter(client, table)
        print(f"{chemin.name} : {lignes} lignes, {len(colonnes)} colonnes")
        print(f"  {', '.join(colonnes)}")


if __name__ == "__main__":
    main()
