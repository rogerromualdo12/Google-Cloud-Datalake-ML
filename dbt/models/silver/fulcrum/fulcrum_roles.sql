WITH source AS (
    SELECT * FROM {{ source('sni_fulcrum', 'roles') }}
),

renamed AS (
    SELECT
        id,
        resource_id,
        name,
        description,
        is_system,
        is_default,
        can_manage_subscription,
        can_update_organization,
        can_manage_members,
        can_manage_roles,
        can_manage_apps,
        can_manage_projects,
        can_manage_choice_lists,
        can_manage_classification_sets,
        can_create_records,
        can_update_records,
        can_delete_records,
        can_change_status,
        can_change_project,
        can_assign_records,
        can_import_records,
        can_export_records,
        can_run_reports,
        owner_id,
        created_by_id,
        updated_by_id,
        created_at,
        updated_at,
        can_manage_layers,
        can_manage_authorizations,
        can_access_issues_and_tasks,
        can_configure_issues_and_tasks,
        can_access_all_projects,
        is_hidden
    FROM source
)

SELECT * FROM renamed
