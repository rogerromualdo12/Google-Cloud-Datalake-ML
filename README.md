# DataMart - installing and running DBT and Airflow


## Prerequisites

Ensure your workstation is setup per engineering requirements:
https://fulcrumapp.atlassian.net/wiki/spaces/ENG/pages/1189675010/Setup+an+Engineering+laptop
NOTE: there is an instruction in these directions to clone the `fulcrum` repo and run `setup`.  This step creates a functioning rails/fulcrum instance in your namespace;  we do NOT need to do this step. 

Also set your umask:
```bash
# Add umask 022 to your `~/.zshrc` file; Airflow needs these permissions to see the DAGs:
echo "umask 022" >> ~/.zshrc
source ~/.zshrc

# Or in the `~/.bash_profile` if using `bash` file:
echo "umask 022" >> ~/.bash_profile
source ~/.bash_profile
```

## Installing DBT

```bash
# Install the required tools `google-cloud-sdk`:
brew install --cask google-cloud-sdk
brew tap dbt-labs/dbt
brew install dbt-bigquery

# Clone the repo and cd into the `datamart/dbt/` folder:
git clone git@github.com:fulcrumapp/datamart.git
cd datamart/dbt/

# Add the `DBT_PROFILES_DIR` variable to your `~/.zshrc` file:
echo "export DBT_PROFILES_DIR=\"$(pwd)/profiles/\"" >> ~/.zshrc
source ~/.zshrc

# Or in the `~/.bash_profile` if using `bash` file:
echo "export DBT_PROFILES_DIR=\"$(pwd)/profiles/\"" >> ~/.bash_profile
source ~/.bash_profile
```

## Running DBT

```bash

# Run the following command in the terminal to autheticate with the Google Cloud account:
gcloud auth application-default login --scopes=https://www.googleapis.com/auth/drive,https://www.googleapis.com/auth/bigquery,https://www.googleapis.com/auth/cloud-platform

cd dbt # from repo top level
dbt debug
```

The output should look like this:

```bash
Running with dbt=1.7.7
dbt version: 1.7.7
python version: 3.11.6
python path: /datamart/dbt/venv/bin/python3.11
os info: macOS-14.2.1-arm64-arm-64bit
Using profiles dir at /datamart/dbt/profiles/
Using profiles.yml file at /datamart/dbt/profiles/profiles.yml
Using dbt_project.yml file at /datamart/dbt/dbt_project.yml
adapter type: bigquery
adapter version: 1.7.4
Configuration:
  profiles.yml file [OK found and valid]
  dbt_project.yml file [OK found and valid]
Required dependencies:
 - git [OK found]
Connection:
  method: oauth
  database: customer-success-273518
  execution_project: customer-success-273518
  schema: dbt_dev
  location: US
  priority: interactive
  maximum_bytes_billed: None
  impersonate_service_account: None
  job_retry_deadline_seconds: None
  job_retries: 1
  job_creation_timeout_seconds: None
  job_execution_timeout_seconds: 300
  keyfile: None
  timeout_seconds: 300
  refresh_token: None
  client_id: None
  token_uri: None
  dataproc_region: None
  dataproc_cluster_name: None
  gcs_bucket: None
  dataproc_batch: None
Registered adapter: bigquery=1.7.4
  Connection test: [OK connection ok]
All checks passed!
```

You should be able to build the whole project with:
```bash
dbt deps
dbt build # builds all tables locally
```

Some other helpful notes:
```
dbt build -s <table name> # builds a specific table

dbt build # runs the inline tests
dbt run # excludes the tests
```

By default, the local environment uses `/dbt/profiles/profiles.yml` and makes changes in GBQ to tables in the dbt_dev schemas.  This file also contains the dbt_qa profile used by Tekton and the dbt_prod profile used for the production tables.  You can use this file locally without harming the production tables.  If for some reason you need your own dev schemas, you can modify the `dataset: dbt_dev` line to `dataset: dbt_dev_foo`.  To avoid pushing this change back to Github, this file is in .gitignore; be aware of this if we need to change the production file. 


## Installing  Airflow

To setup/test Airflow outside of production we will be using a non-production airflow setup.

You will need todo the following:

```bash


# Ensure you are in the checkedout DataMart directory
cd `datamart`

# Log into AWS (needed for decrypting at least)
awslogin

# Ensure you are in the proper context:
chaos

# Ensure your namespace is created:
kubectl create ns $USER

# Add the new helm repo:
helm repo add apache-airflow https://airflow.apache.org

# Change into the charts directory:
cd charts/flcrm-airflow/

# pull in community helm chart:
helm dependency build
```

## Running Airflow

```bash
# Change back to the root code directory:
cd ../../

# Create the airflow cluster:
skaffold dev --cache-artifacts=false
```

Navigate to [http://localhost:8080/](http://localhost:8080/)

User: `admin`
Password: `admin`

At this point you should see the airflow instance and the available DAGs for the branch you are on.  Changing branches will update the DAGs, just as editing them will.

The terminal window you've run skaffold in will continue to tail logs.  You can see your running pods with 
```kubectl -n $USER get po```

You can start over with 
```
helm -n $USER uninstall flcrm-airflow
skaffold dev
```

## CI/CD For pull requests, code formatting and QA (Script `pull-request.yaml`).

### 1. `sqlfluff-lint` Task:

#### Purpose:
This task is dedicated to linting SQL files using [sqlfluff](https://github.com/sqlfluff/sqlfluff), which is a tool for enforcing SQL coding standards and best practices. It's particularly useful in projects using dbt (data build tool) for managing data transformations in SQL.

#### Run Condition:
It is configured to run after the `fetch-repository` task, ensuring that the repository's code is available for linting.

### 2. `python-black-lint` Task:

#### Purpose:
This task uses [black](https://github.com/psf/black), a Python code formatter, to check the formatting of Python files. It's particularly focused on Python files within the Airflow DAGs directory, ensuring they adhere to standard Python formatting guidelines.

#### Run Condition:
Like `sqlfluff-lint`, it runs after the fetch-repository task.

#### Steps:
Runs in a container based on the `python:3.11-slim-buster` image, indicating it's a Python environment.
Sets the working directory to the Airflow DAGs directory in the repository.
The script performs the following actions:
- Installs black using pip.
- Runs black --check . to check the formatting of Python files in the directory.

This command does not change the files but checks if they comply with Black's formatting standards.

### 3. `dbt-build` Task:

#### Purpose:
This task is focused on building, testing, and applying dbt (data build tool) models and tests in a QA environment. dbt is used to transform data in your data warehouse by running SQL queries.

#### Run Condition:
It runs after the sqlfluff-lint and fetch-repository tasks.

#### Workspaces:
Uses the source and bigquery-config workspaces. The latter should contain a bigquery.json file, essential for dbt's BigQuery configuration.

#### Steps:
The task runs in a container based on the `dbt-bigquery` image.
The working directory is set to the dbt directory in the cloned repository.
It sets the `DBT_PROFILES_DIR` environment variable to point to the dbt profiles directory, which is necessary for dbt to find its configuration.

The script within this task executes the following dbt commands:

- `dbt deps`: This command fetches the dbt project's dependencies.
- `dbt build --target qa`: This command runs both `dbt build` and `dbt test`, against the QA environment.

Idealy the users and stakeholders should be checking the results of all `dbt` models/tables in the QA schema `dbt_qa_gold`

## CI/CD For deployment (Script `merge-to-main.yaml`).

### Summary of the `deploy-dbt-airflow` task:

The `deploy-dbt-airflow` task is responsible for deploying the latest versions of dbt project files and Airflow DAGs to a Google Cloud Storage bucket. This deployment is part of a CI/CD process that ensures that changes pushed to the main branch are immediately reflected in the Cloud Composer environment, allowing for automated data pipeline management and execution.

#### Task Trigger and Dependencies:
The `deploy-dbt-airflow` task is set to run after the successful completion of the sqlfluff-lint, python-black-lint, and fetch-repository tasks.
This ensures that the dbt and Airflow code is linted and formatted properly, and the latest version of the code is fetched from the repository before deployment.
Workspaces:

#### The task utilizes two workspaces:
1. `source`: To access the dbt and Airflow DAGs code.

2. `bigquery-config`: Contains the BigQuery JSON configuration file, which is crucial for authentication and configuration when interacting with Google Cloud services.
Deployment Steps:

The task uses a container based on the `google-cloud-cli` image, indicating that it will interact with Google Cloud services.
The script within the task performs the following actions:
- Authenticates with Google Cloud using the service account key file located in the bigquery-config workspace.
Sets the Google Cloud project to `customer-success-273518`.
- Removes existing dbt and Airflow DAGs files from the specified Google Cloud Storage bucket [gs://us-east1-composer-airflow-d-a8f3f2b1-bucket/](https://console.cloud.google.com/storage/browser/us-east1-composer-airflow-d-a8f3f2b1-bucket) to ensure there are no conflicts with the new deployment.
- Copies the new dbt and Airflow DAGs files from the source workspace to the Google Cloud Storage bucket. This is where - Cloud Composer expects to find these files for execution.
