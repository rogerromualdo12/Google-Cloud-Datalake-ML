WITH source AS (
    SELECT * FROM {{ source('s_fulcrum_app', 'form_updated') }}
),

renamed AS (
    SELECT
        context_group_id,
        context_library_name,
        context_library_version,
        context_protocols_source_id,
        created_at,
        description,
        event,
        event_text,
        field_count,
        gallery_app_id,
        id,
        loaded_at,
        name,
        organization_id,
        original_timestamp,
        received_at,
        record_count,
        resource_id,
        sent_at,
        timestamp,
        updated_at,
        user_id,
        uuid_ts,
        version,
        system_type,
        _id,
        advanced_geometry_enabled,
        location_enabled,
        repeatable_advanced_geometry_enabled

    FROM source
)

SELECT * FROM renamed
