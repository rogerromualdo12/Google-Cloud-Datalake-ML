import re
import io
import boto3
import logging
import tempfile
from datetime import datetime

from airflow.utils.dates import days_ago
from airflow.decorators import dag, task

from google.cloud import storage
from google.cloud import bigquery
from google.cloud import secretmanager_v1

import os


CHUNK_SIZE = 100 * 1024 * 1024  # 100 MB chunk size
AWS_BUCKET = "fulcrumapp-data-operations-mongoose"
GCP_BUCKET = "fulcrum-cloud-composer"

FILE_TABLE_MAPPING = {
    # The key is the file name in s3
    # the value is the table name in BigQuery
    "sql/main/billingRevenue.csv": "revenue",
    "sql/main/projects.csv": "projects",
    "sql/main/reportTemplates.csv": "report_templates",
    "sql/main/workflows.csv": "workflows",
    "sql/main/shares.csv": "shares",
    "sql/main/dataShares.csv": "data_shares",
    "sql/main/exports.csv": "exports",
    "sql/main/imports.csv": "imports",
    "sql/main/dataExports.csv": "data_exports",
    "sql/main/views.csv": "views",
    "sql/main/layers.csv": "layers",
    "sql/main/userAgents.csv": "user_agents",
    "sql/main/forms.csv": "forms",
    "sql/main/billingInvoice.csv": "invoices",
    "sql/main/billingManualInvoiceItems.csv": "manual_invoice_items",
    "sql/main/billingManualInvoices.csv": "manual_invoices",
    "sql/main/organizationMemberships.csv": "memberships",
    "sql/main/organizationDeviceRegistrations.csv": "organization_mobile_device_registrations",
    "sql/main/organizations.csv": "organizations",
    "sql/main/billingPlans.csv": "plans",
    "sql/main/billingPromoCodes.csv": "promo_codes",
    "sql/main/roles.csv": "roles",
    "sql/main/billingSubscriptions.csv": "subscriptions",
    "sql/main/users.csv": "users",
    "sql/main/stripe_customers.csv": "stripe_customers",
}


@task(multiple_outputs=True)
def get_aws_creds():
    # Create a client
    client = secretmanager_v1.SecretManagerServiceClient()

    request = secretmanager_v1.AccessSecretVersionRequest(
        name="projects/986031658628/secrets/FME_AWS_CREDS/versions/latest"
    )

    response = client.access_secret_version(request=request)
    payload = response.payload.data.decode("UTF-8")

    # The credentials from your GCP secret (or wherever you sourced them)
    AWS_ACCESS_KEY_ID = re.search(r"aws_access_key_id = (\S+)", payload).group(1)
    AWS_SECRET_ACCESS_KEY = re.search(r"aws_secret_access_key = (\S+)", payload).group(
        1
    )

    credentials = {
        "AWS_ACCESS_KEY_ID": AWS_ACCESS_KEY_ID,
        "AWS_SECRET_ACCESS_KEY": AWS_SECRET_ACCESS_KEY,
    }

    return credentials


@task()
def copy_s3_to_gcs(credentials):
    # Create a session using your credentials
    session = boto3.Session(
        aws_access_key_id=credentials["AWS_ACCESS_KEY_ID"],
        aws_secret_access_key=credentials["AWS_SECRET_ACCESS_KEY"],
    )

    # Create an S3 client
    s3_session = session.client("s3")

    # List objects (files) in the bucket
    response = s3_session.list_objects_v2(Bucket=AWS_BUCKET)

    # Gather all file keys
    files_keys = [obj["Key"] for obj in response.get("Contents", [])]
    files_without_date = [f for f in files_keys if "-" not in f]

    filtered_files_keys = []
    for file_key in files_without_date:
        # file_name = file_key.split("/")[-1].replace(".csv", "")
        if file_key in FILE_TABLE_MAPPING.keys():
            filtered_files_keys.append(file_key)

    # Initialize GCP storage client
    gcp_storage_client = storage.Client()
    gcs_bucket = gcp_storage_client.bucket(GCP_BUCKET)

    gcs_files = []
    for i, file in enumerate(filtered_files_keys):
        logging.info(f"Copying file {file} ({i+1}/{len(filtered_files_keys)})")

        # Create GCS blob
        today = datetime.now().strftime("%Y/%m/%d")
        path = f"staging/fulcrum_admin/{today}/{file.split('/')[-1]}"
        gcs_blob = gcs_bucket.blob(path)

        s3_object = s3_session.get_object(Bucket=AWS_BUCKET, Key=file)
        with s3_object["Body"] as s3_file:
            with tempfile.TemporaryFile() as temp_file:
                while True:
                    chunk = s3_file.read(CHUNK_SIZE)
                    logging.info(f"Chunk for {file}")
                    if not chunk:
                        break
                    temp_file.write(chunk)  # Write chunk to temporary file
                temp_file.seek(0)  # Reset file pointer to the start
                gcs_blob.upload_from_file(temp_file)  # Upload temporary file to GCS

        logging.info(f"File {file} from S3 copied to {path} in GCS.")
        gcs_files.append(path)

    return gcs_files


@task()
def copy_gcs_to_gbq(gcs_files):
    # Initialize a BigQuery client
    client = bigquery.Client()

    gcs_table_mapping = {f[0].split("/")[-1]: f[1] for f in FILE_TABLE_MAPPING.items()}

    for file in gcs_files:
        file_name = file.split("/")[-1]
        table_name = gcs_table_mapping[file_name]

        # Specify GCS bucket and the path of the data you want to load
        gcs_uri = f"gs://fulcrum-cloud-composer/{file}"

        # Specify your BigQuery dataset and table
        dataset_id = "airflow"
        table_id = table_name

        # Get your dataset reference
        dataset_ref = client.dataset(dataset_id)

        # Get your table reference
        table_ref = dataset_ref.table(table_id)

        # # Delete the table if it exists
        # client.delete_table(table_id, not_found_ok=True)

        # Create a job config
        job_config = bigquery.LoadJobConfig()
        job_config.allow_quoted_newlines = True
        job_config.max_bad_records = 15
        job_config.source_format = bigquery.SourceFormat.CSV
        job_config.autodetect = True  # Autodetect the schema
        job_config.ignore_unknown_values = True  # this line allows the job to continue even if some values can not be parsed
        job_config.write_disposition = bigquery.WriteDisposition.WRITE_TRUNCATE

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
            pass

        destination_table = client.get_table(table_ref)
        logging.info("Loaded {} rows.".format(destination_table.num_rows))


@dag(schedule="@daily", start_date=days_ago(1), catchup=False)
def ingest_fulcrum_admin():
    credentials = get_aws_creds()
    gcs_files = copy_s3_to_gcs(credentials)
    copy_gcs_to_gbq(gcs_files)


ingest_fulcrum_admin()
