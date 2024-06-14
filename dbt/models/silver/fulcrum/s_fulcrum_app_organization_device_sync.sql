WITH source AS (
    SELECT * FROM {{ source('s_fulcrum_app', 'organization_device_sync') }}
),

renamed AS (
    SELECT
        application_build,
        application_version,
        context_group_id,
        context_library_name,
        context_library_version,
        context_protocols_source_id,
        event,
        event_text,
        geoip_accuracy,
        geoip_admin_area,
        geoip_country,
        geoip_ip,
        geoip_latitude,
        geoip_locality,
        geoip_location,
        geoip_longitude,
        geoip_postal_code,
        id,
        identifier,
        ip_address,
        loaded_at,
        manufacturer,
        model,
        organization_id,
        original_timestamp,
        platform,
        platform_version,
        received_at,
        resource_id,
        sent_at,
        timestamp,
        user_id,
        uuid_ts

    FROM source
)

SELECT * FROM renamed
