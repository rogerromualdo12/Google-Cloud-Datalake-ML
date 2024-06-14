WITH source AS (
    SELECT * FROM {{ source('sni_fulcrum', 'ita_form_stats') }}
),

renamed AS (
    SELECT
        run_date,
        resource_id,
        name,
        plan_id,
        record_count,
        owner_id,
        system_type

    FROM source
)

SELECT * FROM renamed
