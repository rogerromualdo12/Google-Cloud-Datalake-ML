WITH source AS (
    SELECT * FROM {{ source('sni_fulcrum', 'memberships') }}
),

renamed AS (
    SELECT
        id,
        resource_id,
        activated_at,
        user_id,
        organization_id,
        role_id,
        status,
        created_at,
        updated_at,
        requested_api_key

    FROM source
)

SELECT * FROM renamed
