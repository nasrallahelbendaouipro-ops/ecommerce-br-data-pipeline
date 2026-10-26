"""Flux incrémental : un lot mensuel du jeu test livré par run quotidien.

Chaque run : copie du lot de source/ vers raw/ (5 tables) -> dbt run -> dbt test -> notification.
Le mois livré se calcule à partir de la date logique et du start_date (pas de compteur),
donc un retry ou un clear redonne exactement le même lot : le DAG est idempotent.
"""
from __future__ import annotations

import logging

import pendulum
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import dag, task

log = logging.getLogger(__name__)

PROJECT = "sonorous-lyceum-506109-a5"
BUCKET = "e-commerce-brz"
TABLES = ["orders", "order_items", "payments", "customers", "products"]

START_DATE = pendulum.datetime(2026, 10, 2, tz="UTC")
N_BATCHES = 24
FIRST_BATCH = (2016, 10)

DBT_COMMAND = (
    "/home/airflow/dbt-venv/bin/dbt {command} "
    "--project-dir /opt/airflow/dbt --profiles-dir /opt/airflow/dbt_profiles"
)


def batch_month(logical_date: pendulum.DateTime) -> str:
    index = (logical_date.date() - START_DATE.date()).days
    if not 0 <= index < N_BATCHES:
        raise ValueError(f"Aucun lot prévu pour le {logical_date.date()} (index {index})")
    year, month_index = divmod(FIRST_BATCH[0] * 12 + (FIRST_BATCH[1] - 1) + index, 12)
    return f"{year:04d}-{month_index + 1:02d}"


def log_failure(context) -> None:
    log.error(
        "Échec de la tâche %s (DAG %s, run %s)",
        context["task_instance"].task_id,
        context["dag"].dag_id,
        context["run_id"],
    )


@dag(
    dag_id="ecommerce_br_incremental",
    schedule="@daily",
    start_date=START_DATE,
    end_date=START_DATE.add(days=N_BATCHES - 1),
    catchup=True,
    max_active_runs=1,
    default_args={
        "owner": "data-eng",
        "retries": 1,
        "retry_delay": pendulum.duration(minutes=2),
        "on_failure_callback": log_failure,
    },
    tags=["ecommerce-br", "incremental"],
)
def ecommerce_br_incremental():
    @task(max_active_tis_per_dagrun=5)
    def copy_batch(table: str, logical_date: pendulum.DateTime, ds: str) -> str:
        from google.cloud import storage

        month = batch_month(logical_date)
        bucket = storage.Client(project=PROJECT).bucket(BUCKET)
        source = bucket.blob(f"source/test/{table}/mois={month}/{table}.csv")
        if not source.exists():
            raise FileNotFoundError(f"gs://{BUCKET}/{source.name} introuvable")
        target = f"raw/{table}/load_type=incremental/load_date={ds}/{table}.csv"
        bucket.copy_blob(source, bucket, target)
        return f"gs://{BUCKET}/{target}"

    dbt_run = BashOperator(task_id="dbt_run", bash_command=DBT_COMMAND.format(command="run"))
    dbt_test = BashOperator(task_id="dbt_test", bash_command=DBT_COMMAND.format(command="test"))

    @task
    def notify(logical_date: pendulum.DateTime, ds: str) -> None:
        log.info(
            "Lot %s livré dans raw (load_date=%s) ; dbt run et dbt test terminés.",
            batch_month(logical_date),
            ds,
        )

    copy_batch.expand(table=TABLES) >> dbt_run >> dbt_test >> notify()


ecommerce_br_incremental()
