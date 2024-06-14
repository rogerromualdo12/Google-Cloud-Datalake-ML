FROM apache/airflow:2.7.1

RUN pip3 install opsgenie_sdk stripe flatten_json simple_salesforce
COPY airflow/dags /opt/airflow/dags
