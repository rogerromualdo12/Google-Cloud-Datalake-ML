WITH forms AS (
    SELECT
        form_id,
        resource_id,
        name AS form_name,
        description AS form_description,
        version,
        owner_id,
        record_count,
        record_changed_at,
        bounding_box,
        status,
        record_title_key,
        save_count,
        shared,
        status_field,
        created_by_id,
        updated_by_id,
        gallery_app_id,
        created_at AS form_created_at,
        updated_at,
        auto_assign,
        video_usage,
        video_count,
        photo_usage,
        photo_count,
        signature_usage,
        signature_count,
        total_data_usage,
        total_data_count,
        image,
        image_file_size,
        image_access_key,
        title_field_keys,
        audio_usage,
        audio_count,
        hidden_on_dashboard,
        geometry_types,
        geometry_required,
        projects_enabled,
        assignment_enabled,
        database_size,
        field_count,
        data_field_count,
        repeatable_count,
        barcode_field_count,
        signature_field_count,
        photo_field_count,
        video_field_count,
        audio_field_count,
        calculation_field_count,
        record_link_field_count,
        data_event_size,
        system_type
    FROM {{ ref('fulcrum_forms') }}
),

orgs AS (
    SELECT
        id,
        name AS owner_name,
        resource_id AS org_resource_id
    FROM {{ ref('fulcrum_organizations') }}
)

SELECT
    orgs.org_resource_id,
    forms.form_id,
    forms.resource_id,
    forms.form_name,
    forms.form_description,
    forms.version,
    forms.owner_id,
    orgs.owner_name,
    forms.record_count,
    forms.record_changed_at,
    forms.bounding_box,
    forms.status,
    forms.record_title_key,
    forms.save_count,
    forms.shared,
    forms.status_field,
    forms.created_by_id,
    forms.updated_by_id,
    forms.gallery_app_id,
    forms.form_created_at,
    forms.updated_at,
    forms.auto_assign,
    forms.video_usage,
    forms.video_count,
    forms.photo_usage,
    forms.photo_count,
    forms.signature_usage,
    forms.signature_count,
    forms.total_data_usage,
    forms.total_data_count,
    forms.image,
    forms.image_file_size,
    forms.image_access_key,
    forms.title_field_keys,
    forms.audio_usage,
    forms.audio_count,
    forms.hidden_on_dashboard,
    forms.geometry_types,
    forms.geometry_required,
    forms.projects_enabled,
    forms.assignment_enabled,
    forms.database_size,
    forms.field_count,
    forms.data_field_count,
    forms.repeatable_count,
    forms.barcode_field_count,
    forms.signature_field_count,
    forms.photo_field_count,
    forms.video_field_count,
    forms.audio_field_count,
    forms.calculation_field_count,
    forms.record_link_field_count,
    forms.data_event_size,
    forms.system_type,
    concat(creator.first_name, " ", creator.last_name) AS created_by_name,
    concat(updater.first_name, " ", updater.last_name) AS updated_by_name
FROM forms
INNER JOIN orgs
    ON forms.owner_id = orgs.id
LEFT JOIN {{ ref('fulcrum_users') }} AS fowner
    ON forms.owner_id = fowner.user_id
LEFT JOIN {{ ref('fulcrum_users') }} AS creator
    ON forms.created_by_id = creator.user_id
LEFT JOIN {{ ref('fulcrum_users') }} AS updater
    ON forms.updated_by_id = updater.user_id
