"""Découpe le jeu test en 24 lots mensuels (oct. 2016 -> sept. 2018), un par mois d'achat.

Règles (phase 03) :
- orders : mois de order_purchase_timestamp
- order_items, payments : mois de la commande, via order_id
- customers : mois de la commande du client, via customer_id
- products : une ligne par order_item du mois (doublons conservés, dédoublonnage en staging dbt)
- un mois sans commande produit un CSV avec l'en-tête seul
- orders est écrit au format du train (7 colonnes, même ordre) ; les colonnes absentes
  du test (statut, dates de livraison) sont laissées vides, aucune valeur n'est inventée

Sortie : <out>/source/test/<table>/mois=AAAA-MM/<table>.csv
Usage  : python decouper_lots_test.py <dossier_csv_test> <dossier_sortie>
"""
import sys
from pathlib import Path

import pandas as pd

SRC, OUT = Path(sys.argv[1]), Path(sys.argv[2])
FICHIERS = {
    "orders": "df_Orders.csv",
    "order_items": "df_OrderItems.csv",
    "payments": "df_Payments.csv",
    "customers": "df_Customers.csv",
    "products": "df_Products.csv",
}
MOIS = pd.period_range("2016-10", "2018-09", freq="M")  # 24 mois calendaires

# Tout en texte : les valeurs sont recopiées telles quelles, sans réinterprétation.
t = {k: pd.read_csv(SRC / f, dtype=str, keep_default_na=False) for k, f in FICHIERS.items()}

mois_commande = pd.to_datetime(t["orders"]["order_purchase_timestamp"]).dt.to_period("M")
mois_par_order = dict(zip(t["orders"]["order_id"], mois_commande))
mois_par_client = dict(zip(t["orders"]["customer_id"], mois_commande))

t["orders"]["_mois"] = mois_commande
t["order_items"]["_mois"] = t["order_items"]["order_id"].map(mois_par_order)
t["payments"]["_mois"] = t["payments"]["order_id"].map(mois_par_order)
t["customers"]["_mois"] = t["customers"]["customer_id"].map(mois_par_client)

# products : une ligne par order_item, attributs repris du fichier products (doublons exacts).
attributs = t["products"].drop_duplicates("product_id")
t["products"] = t["order_items"][["product_id", "_mois"]].merge(attributs, on="product_id", how="left")
t["products"] = t["products"][list(attributs.columns) + ["_mois"]]

# Alignement sur le format du train : BigQuery lit les CSV par position.
# Les colonnes absentes du test sont ajoutées vides (NULL), dans l'ordre du train.
COLONNES_TRAIN = {
    "orders": ["order_id", "customer_id", "order_status", "order_purchase_timestamp",
               "order_approved_at", "order_delivered_timestamp", "order_estimated_delivery_date"],
}
for nom, cols in COLONNES_TRAIN.items():
    t[nom] = t[nom].reindex(columns=cols + ["_mois"], fill_value="")

for nom, df in t.items():
    orphelins = df["_mois"].isna().sum()
    if orphelins:
        raise SystemExit(f"{nom} : {orphelins} lignes sans lot (orphelines)")
    colonnes = [c for c in df.columns if c != "_mois"]
    for m in MOIS:
        dossier = OUT / "source" / "test" / nom / f"mois={m}"
        dossier.mkdir(parents=True, exist_ok=True)
        df.loc[df["_mois"] == m, colonnes].to_csv(dossier / f"{nom}.csv", index=False, lineterminator="\n")

# Contrôle de conservation : somme des lots == fichier d'origine
print(f"{'table':<12}{'source':>8}{'lots':>8}  ok")
for nom, f in FICHIERS.items():
    n_src = len(pd.read_csv(SRC / f, dtype=str))
    n_lots = sum(len(pd.read_csv(p, dtype=str)) for p in (OUT / "source" / "test" / nom).glob("mois=*/*.csv"))
    print(f"{nom:<12}{n_src:>8}{n_lots:>8}  {'OK' if n_src == n_lots else 'ECART'}")
