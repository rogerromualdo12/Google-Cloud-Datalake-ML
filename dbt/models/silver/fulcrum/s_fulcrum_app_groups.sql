WITH source AS (
    SELECT * FROM {{ source('s_fulcrum_app', 'groups') }}
),

renamed AS (
    SELECT
        annual_recurring_revenue,
        context_library_name,
        context_library_version,
        context_protocols_source_id,
        context_protocols_violations,
        group_id,
        id,
        industry,
        is_paid_account,
        is_subscription_active,
        loaded_at,
        name,
        org_id,
        original_timestamp,
        received_at,
        sent_at,
        timestamp,
        user_id,
        uuid_ts,
        created_at,
        form_count,
        membership_count,
        plan,
        record_count,
        resource_id,
        sign_up_source,
        subscription_id,
        updated_at,
        converted_at,
        description,
        industry_name,
        anonymous_id,
        context_ip,
        context_locale,
        context_page_path,
        context_page_referrer,
        context_page_title,
        context_page_url,
        context_user_agent,
        context_page_search,
        context_campaign_medium,
        context_campaign_name,
        context_campaign_source,
        context_campaign_content,
        context_campaign_term,
        organization_id,
        partner_code,
        flag_experimental_sync,
        flag_map_engine,
        flag_feature_service_layers_enabled,
        flag_advanced_geometry_enabled,
        flag_groups_enabled,
        flag_import_limit,
        _id,
        flag_web_map_engine,
        context_user_agent_data_brands,
        context_user_agent_data_mobile,
        context_user_agent_data_platform,
        flag_non_blocking_sync_beta,
        flag_non_blocking_sync_production,
        flag_mobile_layer_picker,
        flag_bulk_records_delete_enabled,
        flag_non_blocking_sync_ga,
        flag_reporting_map_engine,
        flag_mobile_offline_feature_services,
        flag_advanced_geometry_beta,
        flag_mobile_layer_picker_ga,
        flag_offline_basemaps_beta,
        flag_offline_basemaps_production,
        flag_advanced_geometry_android,
        flag_advanced_geometry_ios,
        flag_web_sketch_editor,
        flag_tracking_android_enabled,
        flag_tracking_ios_enabled,
        flag_suppress_repeatable_geometry,
        context_timezone,
        repeatable_advanced_geometry_enabled

    FROM source
)

SELECT * FROM renamed
