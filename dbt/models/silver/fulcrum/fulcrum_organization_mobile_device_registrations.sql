WITH source AS (
    SELECT * FROM {{ source('sni_fulcrum', 'organization_mobile_device_registrations') }}
),

renamed AS (
    SELECT
        id,
        resource_id,
        owner_id,
        device_id,
        user_id,
        created_at,
        updated_at
    FROM source
)

SELECT * FROM renamed
