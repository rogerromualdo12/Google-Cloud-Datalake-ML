WITH source AS (
    SELECT * FROM {{ source('sni_fulcrum', 'workflows') }}
),

renamed AS (
    SELECT
        id,
        resource_id,
        created_by_id,
        updated_by_id,
        created_at,
        updated_at,
        owner_id,
        object_type,
        object_resource_id,
        active,
        description,
        name,
        system_type
    FROM source
)

SELECT * FROM renamed
