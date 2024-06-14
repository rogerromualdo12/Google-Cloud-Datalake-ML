# Libraries
import re
import io
from io import StringIO
import logging
import json
from datetime import datetime
import os
import stripe
import datetime as dt
from flatten_json import flatten

from airflow.utils.dates import days_ago
from airflow.decorators import dag, task
from airflow.operators.empty import EmptyOperator
import opsgenie_sdk
from opsgenie_sdk.rest import ApiException
import pandas as pd
from pprint import pprint

from google.cloud import storage
from google.cloud import bigquery
from google.cloud import secretmanager_v1


# Stripe API key
client = secretmanager_v1.SecretManagerServiceClient()
request = secretmanager_v1.AccessSecretVersionRequest(
    name="projects/986031658628/secrets/STRIPE_READ_ONLY/versions/latest"
)
response = client.access_secret_version(request=request)
payload = response.payload.data.decode("UTF-8")
stripe.api_key = payload


# alerts configuration
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
        message=f"DAG fulcrum_stripe_2bq_server failed",
        description="https://2476100040fb4096b11d1065228ca92a-dot-us-east1.composer.googleusercontent.com/dags/ingest_stripe_2bq/grid",
        priority="P5",
    )

    try:
        # Create Alert
        api_response = api_instance.create_alert(create_alert_payload)
        pprint(api_response)
    except ApiException as e:
        print("Exception when calling AlertApi->create_alert: %s\n" % e)
        raise e


CHUNK_SIZE = 100 * 1024 * 1024  # 100 MB chunk size
GCP_BUCKET = "fulcrum_stripe"
CURRENT_DATE = dt.datetime.now()

ENV = "PROD"
if ENV == "DEV":
    bronce_shcema = "airflow_stripe"
    silver_shcema = "airflow_stripe_history"
    snapshot_schema = "airflow_sni_stripe"
    historic_schema = "airflow_stripe_history"
elif ENV == "PROD":
    bronce_shcema = "airflow_stripe"
    silver_shcema = "airflow_stripe_history"
    snapshot_schema = "sni_stripe"
    historic_schema = "sni_stripe_history"

FILE_TABLE_MAPPING_TEMPS = {
    "stripe_subscriptions.json": "subscriptions_temp",
    "stripe_subscription_items.json": "subscription_items_temp",
    "stripe_schedules.json": "schedules_temp",
    "stripe_products.json": "products_temp",
    "stripe_prices.json": "prices_temp",
    "stripe_invoices.json": "invoices_temp",
    "stripe_customers.json": "customers_temp",
}

FILE_TABLE_MAPPING = {
    "stripe_subscriptions.json": "subscriptions",
    "stripe_subscription_items.json": "subscription_items",
    "stripe_schedules.json": "schedules",
    "stripe_products.json": "products",
    "stripe_prices.json": "prices",
    "stripe_invoices.json": "invoices",
    "stripe_customers.json": "customers",
}

FILE_TABLE_MAPPING_HIST = {
    "stripe_subscriptions": "subscriptions",
    "stripe_subscription_items": "subscription_items",
    "stripe_schedules": "schedules",
    "stripe_products": "products",
    "stripe_prices": "prices",
    "stripe_customers": "customers",
}

ENDPOINTS = [
    stripe.SubscriptionSchedule.list,
    stripe.Product.list,
    stripe.Price.list,
    stripe.Customer.list,
]

FILE_NAME_MAPPING = {
    "subscription_schedule": "stripe_schedules.json",
    "product": "stripe_products.json",
    "price": "stripe_prices.json",
    "invoice": "stripe_invoices.json",
    "customer": "stripe_customers.json",
}

start = EmptyOperator(task_id="start")
end = EmptyOperator(task_id="end")


@task()
def create_subs_and_items():
    files_loaded = []
    csv_data = []
    temp_json = "stripe_subscriptions.json"
    temp_json_items = "stripe_subscription_items.json"

    response = stripe.Subscription.list(limit=100, status="all")
    has_more_objects = response.has_more
    last_id = response.data[-1].id

    with open(temp_json, "w", encoding="utf-8") as json_file:
        with open(temp_json_items, "w", encoding="utf-8") as json_file_items:
            for rec in response.data:
                json_file.write(json.dumps(rec) + "\n")
                for item in rec["items"]:
                    json_file_items.write(json.dumps(item) + "\n")

    while has_more_objects:
        response = stripe.Subscription.list(
            limit=100, starting_after=last_id, status="all"
        )
        has_more_objects = response.has_more
        last_id = response.data[-1].id

        with open(temp_json, "a", encoding="utf-8") as json_file:
            with open(temp_json_items, "a", encoding="utf-8") as json_file_items:
                for rec in response.data:
                    json_file.write(json.dumps(rec) + "\n")
                    for item in rec["items"]:
                        json_file_items.write(json.dumps(item) + "\n")

    today = datetime.now().strftime("%Y/%m/%d")
    path = f"{today}/{temp_json}"

    gcp_storage_client = storage.Client()
    gcs_bucket = gcp_storage_client.bucket(GCP_BUCKET)
    gcs_blob = gcs_bucket.blob(path)

    with open(temp_json, "rb") as json_file:
        for count, line in enumerate(json_file):
            tmp_dict = json.loads(line)
            flat_dict = flatten(tmp_dict)
            csv_data.append(flat_dict)
        print("Total Lines " + temp_json, count + 1)
        gcs_blob.upload_from_file(json_file, rewind=True)
        csv_data = pd.json_normalize(csv_data)
        print(temp_json)
        print(temp_json.replace(".json", ".csv"))
        print(path.replace(".json", ".csv"))
        csv_data.to_csv(temp_json.replace(".json", ".csv"))
    with open(temp_json.replace(".json", ".csv"), "rb") as csv_file:
        gcs_blob = gcs_bucket.blob(path.replace(".json", ".csv"))
        gcs_blob.upload_from_file(csv_file, rewind=True)

    print(path)
    files_loaded.append(path)
    path = f"{today}/{temp_json_items}"
    gcs_blob = gcs_bucket.blob(path)
    print(path)
    csv_data = []

    with open(temp_json_items, "rb") as json_file:
        for count, line in enumerate(json_file):
            # line = str(line)
            tmp_dict = json.loads(line)
            flat_dict = flatten(tmp_dict)
            csv_data.append(flat_dict)
        print("Total Lines " + temp_json_items, count + 1)
        gcs_blob.upload_from_file(json_file, rewind=True)
        csv_data = pd.json_normalize(csv_data)
        print(temp_json_items)
        print(temp_json_items.replace(".json", ".csv"))
        print(path.replace(".json", ".csv"))
        csv_data.to_csv(temp_json_items.replace(".json", ".csv"))
    with open(temp_json_items.replace(".json", ".csv"), "rb") as csv_file:
        gcs_blob = gcs_bucket.blob(path.replace(".json", ".csv"))
        gcs_blob.upload_from_file(csv_file, rewind=True)

    files_loaded.append(path)

    return files_loaded


@task()
def create_open_invoices(**context):
    files_loaded = []
    csv_data = []
    temp_json = "invoice.json"
    for status in ["open", "uncollectible"]:
        response = stripe.Invoice.list(limit=100, status=status)
        has_more_objects = response.has_more
        last_id = response.data[-1].id

        if status == "open":
            with open(temp_json, "w", encoding="utf-8") as json_file:
                for rec in response.data:
                    json_file.write(json.dumps(rec) + "\n")

        while has_more_objects:
            response = stripe.Invoice.list(
                limit=100, starting_after=last_id, status=status
            )
            has_more_objects = response.has_more
            last_id = response.data[-1].id

            with open(temp_json, "a", encoding="utf-8") as json_file:
                for rec in response.data:
                    json_file.write(json.dumps(rec) + "\n")

        today = datetime.now().strftime("%Y/%m/%d")
        path = f"{today}/{FILE_NAME_MAPPING.get(str(response.data[-1].object))}"

        gcp_storage_client = storage.Client()
        gcs_bucket = gcp_storage_client.bucket(GCP_BUCKET)
        gcs_blob = gcs_bucket.blob(path)

        with open(temp_json, "rb") as json_file:
            for count, line in enumerate(json_file):
                tmp_dict = json.loads(line)
                flat_dict = flatten(tmp_dict)
                csv_data.append(flat_dict)
            print("Total Lines", count + 1)
            gcs_blob.upload_from_file(json_file, rewind=True)
            csv_data = pd.json_normalize(csv_data)
            print(temp_json)
            print(temp_json.replace(".json", ".csv"))
            print(path.replace(".json", ".csv"))
            csv_data.to_csv(temp_json.replace(".json", ".csv"))
        with open(temp_json.replace(".json", ".csv"), "rb") as csv_file:
            gcs_blob = gcs_bucket.blob(path.replace(".json", ".csv"))
            gcs_blob.upload_from_file(csv_file, rewind=True)

        files_loaded.append(path)

        return files_loaded


@task()
def create_files(endpoint, **context):
    data = []
    csv_data = []
    files_loaded = []
    response = endpoint(limit=100)
    has_more_objects = response.has_more
    last_id = response.data[-1].id
    temp_json = FILE_NAME_MAPPING.get(str(response.data[-1].object))

    with open(temp_json, "w", encoding="utf-8") as json_file:
        for rec in response.data:
            json_file.write(json.dumps(rec) + "\n")

    while has_more_objects:
        response = endpoint(limit=100, starting_after=last_id)
        has_more_objects = response.has_more
        last_id = response.data[-1].id

        with open(temp_json, "a", encoding="utf-8") as json_file:
            for rec in response.data:
                json_file.write(json.dumps(rec) + "\n")

    today = datetime.now().strftime("%Y/%m/%d")
    path = f"{today}/{FILE_NAME_MAPPING.get(str(response.data[-1].object))}"

    gcp_storage_client = storage.Client()
    gcs_bucket = gcp_storage_client.bucket(GCP_BUCKET)
    gcs_blob = gcs_bucket.blob(path)

    with open(temp_json, "rb") as json_file:
        for count, line in enumerate(json_file):
            tmp_dict = json.loads(line)
            flat_dict = flatten(tmp_dict)
            csv_data.append(flat_dict)
        print("Total Lines", count + 1)
        gcs_blob.upload_from_file(json_file, rewind=True)
        csv_data = pd.json_normalize(csv_data)
        print(temp_json)
        print(temp_json.replace(".json", ".csv"))
        print(path.replace(".json", ".csv"))
        csv_data.to_csv(temp_json.replace(".json", ".csv"), encoding="utf-8")
    with open(temp_json.replace(".json", ".csv"), "rb") as csv_file:
        gcs_blob = gcs_bucket.blob(path.replace(".json", ".csv"))
        gcs_blob.upload_from_file(csv_file, rewind=True)

    files_loaded.append(path)

    return files_loaded


@task()
def copy_temp_files(files):
    print(files)
    client = bigquery.Client()

    for file in files:
        table = file.split("/")[-1]
        table_name = FILE_TABLE_MAPPING_TEMPS[table]

        gcs_uri = f"gs://fulcrum_stripe/{file}"
        print("table_name: " + table_name + " file: " + table + " uri: " + gcs_uri)

        dataset_id = bronce_shcema
        table_id = table_name

        # Get your dataset reference
        dataset_ref = client.dataset(dataset_id)

        # Get your table reference
        table_ref = dataset_ref.table(table_id)

        # Create a job config
        job_config = bigquery.LoadJobConfig()
        job_config.allow_quoted_newlines = True
        job_config.max_bad_records = 15
        job_config.schema = [bigquery.SchemaField("json_data", "json")]
        # job_config.source_format = bigquery.SourceFormat.NEWLINE_DELIMITED_JSON
        job_config.field_delimiter = "\x10"
        # job_config.autodetect = True  # Autodetect the schema
        job_config.ignore_unknown_values = True  # this line allows the job to continue even if some values can not be parsed
        job_config.write_disposition = "WRITE_TRUNCATE"

        # Run the job
        load_job = client.load_table_from_uri(gcs_uri, table_ref, job_config=job_config)

        logging.info(f"Starting job for table '{table_id}'")

        try:
            load_job.result()  # Waits for table load to complete.
            logging.info("Job finished.")
        except Exception as e:
            logging.error(
                f"Errors occurred during job execution for table '{table_id}':"
            )
            for error in load_job.errors:
                logging.error(error)
            raise e

        destination_table = client.get_table(table_ref)
        logging.info("Loaded {} rows.".format(destination_table.num_rows))


@task()
def insert_bronce():
    client = bigquery.Client()
    bronce_tables = FILE_TABLE_MAPPING.values()
    print(bronce_tables)

    for table in bronce_tables:
        last_date = f"""SELECT coalesce(substr(max(run_date), 1, 8), '19900101') last_date FROM {bronce_shcema}.{table}"""

        create_sql = f"""CREATE TABLE IF NOT EXISTS {bronce_shcema}.{table} AS 
                    SELECT string(json_data.id) as id
                    , string(json_data.object) as object
                    , replace(replace(replace(string(current_datetime()),'-',''),':',''),' ','') as run_date
                    , json_data
                    FROM {bronce_shcema}.{table}_temp
                    """

        create_job = client.query(create_sql)
        create_job.result()
        date_job = client.query(last_date)
        date = date_job.result()
        last_run = [d.last_date for d in date][0]

        insert_sql = f"""INSERT INTO {bronce_shcema}.{table} 
                    SELECT string(json_data.id) as id
                    , string(json_data.object) as object
                    , replace(replace(replace(string(current_datetime()),'-',''),':',''),' ','') as run_date
                    , json_data
                    FROM {bronce_shcema}.{table}_temp
                    WHERE cast(replace(replace(replace(string(current_date()),'-',''),':',''),' ','') as int) > {last_run}
                    """

        delete_temp_sql = f"""DROP TABLE {bronce_shcema}.{table}_temp"""

        try:
            insert_job = client.query(insert_sql)
            insert_job.result()
            delete_job = client.query(delete_temp_sql)
            delete_job.result()
            print(f"Job finished for '{table}'.")
            print(last_run)

        except Exception as e:
            logging.error(f"Errors occurred during job execution for table '{table}':")
            for error in insert_job.errors:
                logging.error(error)
            raise e


@task()
def copy_gcs_to_gbq_snapshot(files):
    client = bigquery.Client()

    # Create temp tables
    for file in files:
        key = file.split("/")[-1]
        csv_file = file.replace(".json", ".csv")
        table_name_temp = FILE_TABLE_MAPPING[key] + "_temp"
        table_name = FILE_TABLE_MAPPING[key]

        gcs_uri = f"gs://fulcrum_stripe/{csv_file}"
        print(
            "table_name: " + table_name_temp + " file: " + csv_file + " uri: " + gcs_uri
        )

        dataset_id = snapshot_schema
        table_id = table_name_temp

        # Get your dataset reference
        dataset_ref = client.dataset(dataset_id)

        # Get your table reference
        table_ref = dataset_ref.table(table_id)

        # Create a job config
        job_config = bigquery.LoadJobConfig()
        job_config.allow_quoted_newlines = True
        job_config.max_bad_records = 15
        job_config.source_format = bigquery.SourceFormat.CSV
        job_config.encoding = "UTF-8"
        job_config.autodetect = True  # Autodetect the schema
        job_config.ignore_unknown_values = True  # this line allows the job to continue even if some values can not be parsed
        job_config.write_disposition = "WRITE_TRUNCATE"

        # Run the job
        load_job = client.load_table_from_uri(gcs_uri, table_ref, job_config=job_config)

        logging.info(f"Starting job for table '{table_id}'")

        try:
            load_job.result()  # Waits for table load to complete.
            logging.info("Job finished.")
        except Exception as e:
            logging.error(
                f"Errors occurred during job execution for table '{table_id}':"
            )
            for error in load_job.errors:
                logging.error(error)
            raise e

        destination_table = client.get_table(table_ref)
        logging.info("Loaded {} rows.".format(destination_table.num_rows))

        path = os.getcwd()
        with open(path + "/gcs/dags/fulcrum_stripe_2bq_server/stripe_schema.json") as f:
            d = json.load(f)

        columns = str(d[table_name]).replace("[", "").replace("]", "").replace("'", "")

        insert_sql = f"""CREATE OR REPLACE TABLE {snapshot_schema}.{table_name} AS
                        SELECT {columns}, replace(replace(replace(string(current_datetime()),'-',''),':',''),' ','') AS run_date
                        FROM {snapshot_schema}.{table_name_temp}"""
        print(insert_sql)
        client = bigquery.Client()
        insert_job = client.query(insert_sql)
        insert_job.result()


@task()
def insert_historic():
    path = os.getcwd()

    # prod folder
    with open(path + "/gcs/dags/fulcrum_stripe_2bq_server/stripe_schema_fme.json") as f:
        d = json.load(f)

    client = bigquery.Client()
    for file in FILE_TABLE_MAPPING_HIST.keys():
        table_name = FILE_TABLE_MAPPING_HIST[file]
        columns = str(d[table_name]).replace("[", "").replace("]", "").replace("'", "")

        last_date = f"""SELECT coalesce(substr(max(run_date), 1, 8), '19900101') last_date FROM {historic_schema}.{table_name}"""

        date_job = client.query(last_date)
        date = date_job.result()
        last_run = [d.last_date for d in date][0]

        insert = f"""INSERT INTO {historic_schema}.{table_name}
                SELECT {columns}, replace(replace(replace(string(current_datetime()),'-',''),':',''),' ','')
                FROM {snapshot_schema}.{table_name}_temp
                WHERE cast(replace(replace(replace(string(current_date()),'-',''),':',''),' ','') as int) > {last_run}
                """

        logging.info(f"Starting job for table '{table_name}'")

        try:
            insert_job = client.query(insert)
            insert_job.result()
            drop_sql = f"""DROP TABLE {snapshot_schema}.{table_name}_temp"""
            drop_job = client.query(drop_sql)
            drop_job.result()
            print("Job finished.")
        except Exception as e:
            logging.error(
                f"Errors occurred during job execution for table '{table_name}':"
            )
            for error in insert_job.errors:
                logging.error(error)
            raise e


@dag(
    schedule="0 12 * * *",
    start_date=days_ago(1),
    catchup=False,
    on_failure_callback=create_alert,
    concurrency=5.0,
)
def ingest_stripe_2bq():
    create_s = create_subs_and_items()
    create_i = create_open_invoices()
    copy_files_s = copy_temp_files.override(task_id="copy_subs")(create_s)
    copy_files_i = copy_temp_files.override(task_id="copy_invoices")(create_i)
    copy_csv_invoice = copy_gcs_to_gbq_snapshot.override(task_id="copy_invoices_csv")(
        create_i
    )
    copy_csv_subs = copy_gcs_to_gbq_snapshot.override(task_id="copy_subs_csv")(create_s)
    # copy_snapshots = copy_snapshot_files()
    bronce = insert_bronce()
    historic = insert_historic()

    for endpoint in ENDPOINTS:
        create_task = create_files.override(
            task_id=f"create_{str(endpoint).split('.')[0].split(' ')[-1]}_file"
        )(endpoint)
        copy_files = copy_temp_files.override(
            task_id=f"copy_{str(endpoint).split('.')[0].split(' ')[-1]}_file"
        )(create_task)
        copy_csv_files = copy_gcs_to_gbq_snapshot.override(
            task_id=f"copy_{str(endpoint).split('.')[0].split(' ')[-1]}_csv_file"
        )(create_task)
        start >> [create_s, create_i, create_task]
        create_s >> [copy_files_s, copy_csv_subs]
        create_i >> [copy_files_i, copy_csv_invoice]
        create_task >> [copy_files, copy_csv_files]
        [copy_files_s, copy_files_i, copy_files] >> bronce >> end
        [copy_csv_invoice, copy_csv_subs, copy_csv_files] >> historic >> end
        # copy_temp_files(current_task)#>> copy_snap >> historic


ingest_stripe_2bq()
