import re
import io
from io import StringIO
import logging
import json
from datetime import datetime, timedelta
import time
import os
import stripe
import datetime as dt
from flatten_json import flatten
import pytz

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

client = secretmanager_v1.SecretManagerServiceClient()
request = secretmanager_v1.AccessSecretVersionRequest(
    name="projects/986031658628/secrets/STRIPE_FULL/versions/latest"
)
response = client.access_secret_version(request=request)
payload = response.payload.data.decode("UTF-8")
stripe.api_key = payload


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
        message="DAG customer_status_2stripe failed",
        description="https://2476100040fb4096b11d1065228ca92a-dot-us-east1.composer.googleusercontent.com/dags/customer_status_2stripe/grid",
        priority="P5",
    )

    try:
        # Create Alert
        api_response = api_instance.create_alert(create_alert_payload)
        pprint(api_response)
    except ApiException as e:
        print("Exception when calling AlertApi->create_alert: %s\n" % e)


# -------------------------------------------------------------------------------------------------------------------
def stripe_get_data(resource, start_date=None, end_date=None, **kwargs):
    if start_date:
        # convert to unix timestamp
        start_date = int(start_date.timestamp())
    if end_date:
        # convert to unix timestamp
        end_date = int(end_date.timestamp())
    if resource == "Subscription":
        resource_list = getattr(stripe, resource).list(
            limit=100000,
            created={"gte": start_date, "lt": end_date},
            status="all",
            **kwargs,
        )
    else:
        resource_list = getattr(stripe, resource).list(
            limit=100000, created={"gte": start_date, "lt": end_date}, **kwargs
        )
    lst = []
    for i in resource_list.auto_paging_iter():
        lst.extend([i])
    df = pd.DataFrame(lst)
    if not df.empty:
        df["created"] = pd.to_datetime(df["created"], unit="s")
    return df


# -------------------------------------------------------------------------------------------------------------------
def find_subs_info(iprd_coll, i_cust_id):
    subs_id = ""
    conta = 0
    cancel = 0
    status = ""
    flag = ""
    cancel_date = ""
    major_date = ""
    if i_cust_id == "":
        return subs_id, conta, status
    for i in iprd_coll.index:
        if iprd_coll["customer"][i] == i_cust_id:
            conta = conta + 1
            subs_id = subs_id + "; " + iprd_coll["id"][i]
            status = iprd_coll["status"][i]
            if status == "canceled":
                cancel = cancel + 1
                cancel_date = int(iprd_coll["canceled_at"][i])  # + timedelta(days=93))
                if major_date == "" or cancel_date >= major_date:
                    major_date = cancel_date
                cancel_date = (
                    datetime.utcfromtimestamp(major_date) + timedelta(days=93)
                ).strftime("%Y-%m-%d")
            else:
                flag = status
    if conta == cancel:
        status = "canceled"
    else:
        status = flag
        cancel_date = ""
    if conta == 0:
        status = ""
        cancel_date = ""
    return subs_id, conta, status, cancel_date


# -------------------------------------------------------------------------------------------------------------------
@task()
def update_customer_status():
    current_date = datetime.now(pytz.timezone("UTC"))
    current_date = current_date.strftime("%Y%m%d_%H%M%S")

    stripe.api_version = "2020-08-27"
    # --------------------Retrieve "all" customers -----------------------------------------------------------------
    df = stripe_get_data("Customer")
    # --------------------Retrieve "all" subscriptions  --- ---------------------------------------------------------
    dfs = stripe_get_data("Subscription")

    i = 0
    # if 1==1:
    for i in df.index:
        customer_id = df["id"][i]
        subs_id, subs_conta, subs_stts, cancel_date = find_subs_info(dfs, customer_id)
        print(
            str(i)
            + ": "
            + customer_id
            + ": "
            + subs_id
            + ": "
            + str(subs_conta)
            + ": "
            + subs_stts
        )
        if subs_id != "":
            stripe.Customer.modify(
                customer_id,
                metadata={"status": subs_stts, "delete_by": cancel_date},
            )


@dag(
    schedule="0 5 * * *",
    start_date=days_ago(1),
    catchup=False,
    on_failure_callback=create_alert,
    concurrency=5.0,
)
def customer_status_2stripe():
    update_customer_status()


customer_status_2stripe()
