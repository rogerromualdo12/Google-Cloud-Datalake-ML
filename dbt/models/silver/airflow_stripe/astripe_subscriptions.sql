WITH max_date AS (
    SELECT max(substr(run_date, 1, 8)) AS max_date FROM {{ source('airflow_stripe', 'subscriptions') }}
),

source AS (
    SELECT s.* FROM {{ source('airflow_stripe', 'subscriptions') }} AS s
    INNER JOIN max_date
        ON substr(s.run_date, 1, 8) = max_date.max_date
),

renamed AS (
    SELECT *
    FROM source
)

SELECT * FROM renamed
