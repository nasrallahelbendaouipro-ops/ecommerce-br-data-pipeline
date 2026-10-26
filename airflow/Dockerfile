FROM apache/airflow:3.3.2

# dbt vit dans son propre environnement virtuel, avec les versions figées de requirements.txt,
# pour ne pas entrer en conflit avec les dépendances d'Airflow.
COPY --chown=airflow:root requirements.txt /tmp/dbt-requirements.txt
RUN python -m venv /home/airflow/dbt-venv \
    && /home/airflow/dbt-venv/bin/pip install --no-cache-dir -r /tmp/dbt-requirements.txt
