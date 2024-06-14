from simple_salesforce import Salesforce
import json
from flatten_json import flatten
import logging
from datetime import datetime, timezone

from airflow.utils.dates import days_ago
from airflow.decorators import dag, task
from airflow.operators.empty import EmptyOperator

from google.cloud import storage
from google.cloud import bigquery
from google.cloud import secretmanager_v1


CHUNK_SIZE = 100 * 1024 * 1024  # 100 MB chunk size
GCP_BUCKET = "sfdc_gbq_staging"
CURRENT_DATE = datetime.now(timezone.utc)
client = secretmanager_v1.SecretManagerServiceClient()
request = secretmanager_v1.AccessSecretVersionRequest(
    name="projects/986031658628/secrets/salesforce-auth/versions/latest"
)
response = client.access_secret_version(request=request)
payload = response.payload.data.decode("UTF-8")
payload = json.loads(payload)

ENV = "DEV"
if ENV == "DEV":
    bronce_schema = "airflow_salesforce"
    silver_schema = "airflow_salesforce_history"
    snapshot_schema = "airflow_sni_salesforce"
    historic_schema = "airflow_sni_salesforce_history"
elif ENV == "PROD":
    bronce_schema = "airflow_salesforce"
    silver_schema = "airflow_salesforce_history"
    snapshot_schema = "sni_saleforce"
    historic_schema = "sni_saleforce_history"

object_names = [
    "Account",
    "Campaign",
    "Contact",
    "OpportunityLineItem",
    "Task",
    "Event",
    "Opportunity",
]

start = EmptyOperator(task_id="start")
end = EmptyOperator(task_id="end")

sf = Salesforce(
    username=payload["username"],
    password=payload["password"],
    security_token=payload["security_token"],
)  # loop for every object
gcp_storage_client = storage.Client()
gcs_bucket = gcp_storage_client.bucket(GCP_BUCKET)
today = datetime.now(timezone.utc).strftime("%Y/%m/%d")


@task()
def sf_2_gcs(object):
    object_description = sf.__getattr__(object).describe()
    field_names = [field["name"] for field in object_description["fields"]]
    soql_query = f"SELECT {', '.join(field_names)} FROM {object}"
    results = sf.query(soql_query)
    path = f"{today}/" + object + ".json"
    gcs_blob = gcs_bucket.blob(path)
    while results["done"] == False:
        # print(str(results["done"]) + " " + results["nextRecordsUrl"])
        results = sf.query_more(results["nextRecordsUrl"], True)
        # print(str(results["done"]))  # + ' ' + results["nextRecordsUrl"])
        with gcs_blob.open("w", encoding="utf-8") as json_file:
            for rec in results["records"]:
                rec.pop("attributes", None)
                json_file.write(json.dumps(rec) + "\n")
                # print(json.dumps(rec) + "\n")
    return path


@task()
def sf_gcs_2_gbq(object):
    bqclient = bigquery.Client()
    path = f"{today}/" + object + ".json"
    gcs_uri = f"gs://{GCP_BUCKET}/{path}"
    dataset_id = "sni_salesforce_history_test"
    location = "US"
    table_id = object + "_temp"
    dataset_ref = bqclient.dataset(dataset_id)
    dataset = bigquery.Dataset(dataset_ref)
    dataset.location = location
    table_ref = dataset_ref.table(table_id)
    job_config = bigquery.LoadJobConfig()
    job_config.allow_quoted_newlines = True
    job_config.max_bad_records = 15
    job_config.schema = [bigquery.SchemaField("json_data", "json")]
    job_config.field_delimiter = "\x10"
    job_config.source_format = bigquery.SourceFormat.CSV
    job_config.autodetect = True  # Autodetect the schema
    job_config.ignore_unknown_values = True  # this line allows the job to continue even if some values can not be parsed
    # # Run the job
    load_job = bqclient.load_table_from_uri(gcs_uri, table_ref, job_config=job_config)
    logging.info(f"Starting job for table '{table_id}'")
    try:
        load_job.result()  # Waits for table load to complete.
        logging.info("Job finished.")
    except Exception:
        logging.error(f"Errors occurred during job execution for table '{table_id}':")
        for error in load_job.errors:
            logging.error(error)
    destination_table = bqclient.get_table(table_ref)
    logging.info("Loaded {} rows.".format(destination_table.num_rows))


@task()
def insert_historic(object):
    schema = "sni_salesforce_history_test"
    table = object
    temp_table = object + "_temp"
    # BQ Client
    client = bigquery.Client()
    # Last date
    last_date_sql = f"""SELECT coalesce(substr(max(run_date), 1, 8), '19900101') last_date FROM {schema}.{table}"""
    # Date query
    date_job = client.query(last_date_sql)
    date = date_job.result()
    last_run = [d.last_date for d in date][0]
    # Insert query
    insert_sql = f"""INSERT INTO {schema}.{table}
                    SELECT json_value(json_data.Id) AS id, json_data, replace(replace(replace(string(current_datetime()),'-',''),':',''),' ','')
                    FROM {schema}.{temp_table}
                    WHERE cast(replace(replace(replace(string(current_date()),'-',''),':',''),' ','') as int) > {last_run}"""
    # Drop Query
    drop_sql = f"DROP TABLE {schema}.{temp_table}"
    # Execution
    try:
        insert_job = client.query(insert_sql)
        insert_job.result()
        drop_job = client.query(drop_sql)
        drop_job.result()
        print("Job finished.")
    except Exception:
        logging.error(f"Errors occurred during job execution for table '{table}':")
        for error in insert_job.errors:
            logging.error(error)


@dag(
    schedule="0 12 * * *",
    start_date=days_ago(1),
    catchup=False,
    concurrency=5.0,
)
def ingest_sfdc_2_bq_test():
    for object in object_names:
        (sf_2_gcs(object) >> sf_gcs_2_gbq(object) >> insert_historic(object))


ingest_sfdc_2_bq_test()
