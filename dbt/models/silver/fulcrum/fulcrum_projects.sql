WITH source AS (
    SELECT * FROM {{ source('sni_fulcrum', 'projects') }}
),

renamed AS (
    SELECT
        id,
        resource_id,
        bounding_box,
        name,
        description,
        status,
        record_count,
        created_by_id,
        owner_id,
        created_at,
        updated_at,
        customer,
        external_job_id,
        project_manager_id,
        start_date,
        end_date,
        form_count,
        record_changed_at

    FROM source
)

SELECT * FROM renamed
