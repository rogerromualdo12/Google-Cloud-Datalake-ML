WITH source AS (
    SELECT * FROM {{ source('sni_fulcrum', 'organization_mobile_devices') }}
),

renamed AS (
    SELECT
        id,
        resource_id,
        owner_id,
        identifier,
        platform,
        platform_version,
        manufacturer,
        model,
        application_version,
        application_build,
        ip_address,
        created_at,
        updated_at

    FROM source
)

SELECT * FROM renamed
