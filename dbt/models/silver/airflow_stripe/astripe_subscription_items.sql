WITH max_date AS (
    SELECT max(substr(run_date, 1, 8)) AS max_date FROM {{ source('airflow_stripe', 'subscription_items') }}
),

source AS (
    SELECT si.* FROM {{ source('airflow_stripe', 'subscription_items') }} AS si
    INNER JOIN max_date
        ON substr(si.run_date, 1, 8) = max_date.max_date
),

renamed AS (
    SELECT *
    FROM source
)

SELECT * FROM renamed
