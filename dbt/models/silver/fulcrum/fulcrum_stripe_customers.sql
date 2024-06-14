WITH source AS (
    SELECT * FROM {{ source('sni_fulcrum', 'stripe_customers') }}
),

renamed AS (
    SELECT
        id,
        organization_id,
        customer_id
    FROM source
)

SELECT * FROM renamed
