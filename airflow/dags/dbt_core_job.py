from airflow.utils.dates import days_ago
from airflow.decorators import dag, task
from airflow.operators.bash import BashOperator

import os


@task()
def copy_dbt_project():
    BashOperator(
        task_id="rm",
        bash_command="[ -d /tmp/dbt/ ] && rm -rf /tmp/dbt/ || echo 'Directory `dbt` does not exist'",
    ).execute({})
    BashOperator(
        task_id="cp",
        bash_command="gsutil -m cp -r gs://us-east1-composer-airflow-d-a8f3f2b1-bucket/dbt/ /tmp/",
    ).execute({})
    BashOperator(task_id="ls", bash_command="cd /tmp/dbt/ && ls -l").execute({})


@task()
def dbt_deps():
    BashOperator(task_id="deps", bash_command="cd /tmp/dbt/ && dbt deps").execute({})
    BashOperator(
        task_id="debug",
        bash_command="cd /tmp/dbt/ && dbt debug --profiles-dir profiles/ --target prod",
    ).execute({})


@task()
def dbt_freshness():
    BashOperator(
        task_id="freshness",
        bash_command="cd /tmp/dbt/ && dbt source freshness --profiles-dir profiles/ --target prod",
    ).execute({})


@task()
def dbt_build():
    BashOperator(
        task_id="build",
        bash_command="cd /tmp/dbt/ && dbt build --profiles-dir profiles/ --target prod",
    ).execute({})


# Define the DAG using the dag decorator
@dag(schedule="@daily", start_date=days_ago(1), catchup=False)
def dbt_core_job():
    copy_dbt_project_taks = copy_dbt_project()
    dbt_deps_task = dbt_deps()
    dbt_freshness_task = dbt_freshness()
    dbt_build_task = dbt_build()

    copy_dbt_project_taks >> dbt_deps_task >> dbt_freshness_task >> dbt_build_task


dbt_core_job()
