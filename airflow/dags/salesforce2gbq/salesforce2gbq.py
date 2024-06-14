import os
import io
import re
from simple_salesforce import Salesforce
import json
from flatten_json import flatten
import logging
from datetime import datetime
import opsgenie_sdk
from opsgenie_sdk.rest import ApiException
import pprint

from airflow.utils.dates import days_ago
from airflow.decorators import dag, task
from airflow.operators.empty import EmptyOperator

from google.cloud import storage
from google.cloud import bigquery
from google.cloud import secretmanager_v1


def create_alert(context):
    client = secretmanager_v1.SecretManagerServiceClient()
    request = secretmanager_v1.AccessSecretVersionRequest(
        name="projects/986031658628/secrets/data_ops_opsgenie/versions/latest"
    )
    response = client.access_secret_version(request=request)
    payload = response.payload.data.decode("UTF-8")
    # Create a client
    configuration = opsgenie_sdk.Configuration()
    # Configure API key authorization: GenieKey
    configuration.api_key["Authorization"] = payload

    api_instance = opsgenie_sdk.AlertApi(opsgenie_sdk.ApiClient(configuration))
    create_alert_payload = opsgenie_sdk.CreateAlertPayload(
        message=f"DAG salesforce2gbq failed",
        description="https://2476100040fb4096b11d1065228ca92a-dot-us-east1.composer.googleusercontent.com/dags/ingest_sfdc_2bq/grid",
        priority="P5",
    )

    try:
        # Create Alert
        api_response = api_instance.create_alert(create_alert_payload)
        pprint(api_response)
    except ApiException as e:
        print("Exception when calling AlertApi->create_alert: %s\n" % e)


CHUNK_SIZE = 100 * 1024 * 1024  # 100 MB chunk size
GCP_BUCKET = "sfdc_gbq_staging"
# os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "/Users/javierlopez/.ssh/customer-success-273518-25074570020e.json"
# get auth
client = secretmanager_v1.SecretManagerServiceClient()
request = secretmanager_v1.AccessSecretVersionRequest(
    name="projects/986031658628/secrets/salesforce-auth/versions/latest"
)
response = client.access_secret_version(request=request)
payload = response.payload.data.decode("UTF-8")
payload = json.loads(payload)


@task()
def sf2gcs():
    data = []
    sf = Salesforce(
        username=payload["username"],
        password=payload["password"],
        security_token=payload["security_token"],
    )
    print("authenticated")

    desc = sf.bizible2__Bizible_Attribution_Touchpoint__c.describe()

    # Below is what you need
    field_names = [field["name"] for field in desc["fields"]]
    soql = "SELECT {} FROM bizible2__Bizible_Attribution_Touchpoint__c".format(
        ",".join(field_names)
    )

    results = sf.query(soql)
    with open("temp_bizible2.json", "w", encoding="utf-8") as json_file:
        for rec in results["records"]:
            rec.pop("attributes", None)
            json_file.write(json.dumps(rec) + "\n")
            print(json.dumps(rec) + "\n")

    while results["done"] == False:
        print(str(results["done"]) + " " + results["nextRecordsUrl"])
        results = sf.query_more(results["nextRecordsUrl"], True)
        print(str(results["done"]))  # + ' ' + results["nextRecordsUrl"])
        with open("temp_bizible2.json", "a", encoding="utf-8") as json_file:
            for rec in results["records"]:
                rec.pop("attributes", None)
                json_file.write(json.dumps(rec) + "\n")

        # Create GCS blob
        gcp_storage_client = storage.Client()
        gcs_bucket = gcp_storage_client.bucket(GCP_BUCKET)
        today = datetime.now().strftime("%Y/%m/%d")
        path = f"{today}/bizible2__Bizible_Attribution_Touchpoint__c.json"
        gcs_blob = gcs_bucket.blob(path)
        storage.blob._DEFAULT_CHUNKSIZE = 2097152  # 1024 * 1024 B * 2 = 2 MB
        storage.blob._MAX_MULTIPART_SIZE = 2097152  # 2 MB

    # with open("temp_bizible2.json", "rb") as json_file:
    #     while True:
    #         chunk = json_file.read(CHUNK_SIZE)
    #         logging.info(f"Chunk for bizible2__Bizible_Attribution_Touchpoint__c")
    #         if not chunk:
    #             break
    #         #file_like_chunk = io.BytesIO(chunk)  # Convert bytes to file-like object
    #         gcs_blob.upload_from_file(
    #             json_file, rewind=True
    #         )  # Make sure the position is set to the start

    with open("temp_bizible2.json", "rb") as json_file:
        for count, line in enumerate(json_file):
            pass
        print("Total Lines", count + 1)
        gcs_blob.upload_from_file(json_file, rewind=True)

    return path


@task()
def sf_gcs_2_gbq(file):
    client = bigquery.Client()

    file_name = file.split("/")[-1]
    table_name = file_name.split(".")[0]

    # Specify GCS bucket and the path of the data you want to load
    gcs_uri = f"gs://{GCP_BUCKET}/{file}"

    # Specify your BigQuery dataset and table
    dataset_id = "sni_salesforce_history"
    table_id = "bizible2__Bizible_Attribution_Touchpoint__c_temp"

    # Get your dataset reference
    dataset_ref = client.dataset(dataset_id)

    # Get your table reference
    table_ref = dataset_ref.table(table_id)

    # Create a job config
    job_config = bigquery.LoadJobConfig()
    job_config.allow_quoted_newlines = True
    job_config.max_bad_records = 15
    job_config.schema = [bigquery.SchemaField("json_data", "json")]
    job_config.field_delimiter = "\x10"
    # job_config.source_format = bigquery.SourceFormat.CSV
    # job_config.autodetect = True  # Autodetect the schema
    job_config.ignore_unknown_values = True  # this line allows the job to continue even if some values can not be parsed

    # Run the job
    load_job = client.load_table_from_uri(gcs_uri, table_ref, job_config=job_config)

    logging.info(f"Starting job for table '{table_id}'")

    try:
        load_job.result()  # Waits for table load to complete.
        logging.info("Job finished.")
    except Exception as e:
        logging.error(f"Errors occurred during job execution for table '{table_id}':")
        for error in load_job.errors:
            logging.error(error)
        pass

    destination_table = client.get_table(table_ref)
    logging.info("Loaded {} rows.".format(destination_table.num_rows))


@task()
def intert_historic():
    schema = "sni_salesforce_history"
    table = "bizible2__Bizible_Attribution_Touchpoint__c"
    temp_table = "bizible2__Bizible_Attribution_Touchpoint__c_temp"

    client = bigquery.Client()

    create_sql = f"""CREATE TABLE IF NOT EXISTS {schema}.{table} AS
                    SELECT json_value(json_data.Id) AS id
                    ,json_data
                    , replace(replace(replace(string(current_datetime()),'-',''),':',''),' ','') AS run_date
                    FROM {schema}.{temp_table}"""

    create_job = client.query(create_sql)
    create = create_job.result()

    last_date_sql = f"""SELECT coalesce(substr(max(run_date), 1, 8), '19900101') last_date FROM {schema}.{table}"""

    date_job = client.query(last_date_sql)
    date = date_job.result()
    last_run = [d.last_date for d in date][0]

    insert_sql = f"""INSERT INTO {schema}.{table}
                    SELECT json_value(json_data.Id) AS id, json_data, replace(replace(replace(string(current_datetime()),'-',''),':',''),' ','')
                    FROM {schema}.{temp_table}
                    WHERE cast(replace(replace(replace(string(current_date()),'-',''),':',''),' ','') as int) > {last_run}"""

    drop_sql = f"DROP TABLE {schema}.{temp_table}"

    try:
        insert_job = client.query(insert_sql)
        insert_job.result()
        drop_job = client.query(drop_sql)
        drop_job.result()
        print("Job finished.")
    except Exception as e:
        logging.error(f"Errors occurred during job execution for table '{table}':")
        for error in insert_job.errors:
            logging.error(error)
        pass


@dag(
    schedule="0 12 * * *",
    start_date=days_ago(1),
    catchup=False,
    on_failure_callback=create_alert,
    concurrency=5.0,
)
def ingest_sfdc_2bq():
    sf_gcs_2_gbq(sf2gcs()) >> intert_historic()


ingest_sfdc_2bq()
