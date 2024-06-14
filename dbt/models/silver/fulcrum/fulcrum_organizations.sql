WITH source AS (
    SELECT * FROM {{ source('sni_fulcrum', 'organizations') }}
),

renamed AS (
    SELECT
        id,
        resource_id,
        api_usage,
        name,
        description,
        locality,
        region,
        street_address,
        country,
        extended_address,
        postal_code,
        email,
        gravatar_email,
        created_by_id,
        partnership_id,
        created_at,
        updated_at,
        video_usage,
        video_count,
        photo_usage,
        photo_count,
        signature_usage,
        signature_count,
        total_data_usage,
        total_data_count,
        industry_id,
        notes,
        industry_name,
        audio_usage,
        audio_count,
        form_count,
        record_count,
        membership_count,
        customer_name,
        billing_address_line1,
        billing_address_line2,
        billing_address_line3,
        billing_address_line4,
        billing_address_line5,
        device_count,
        purchase_order_number,
        attn_field,
        billing_emails,
        active_device_count,
        instance_name,
        total_revenue,
        monthly_revenue,
        database_size,
        projects_enabled_default,
        assignment_enabled_default,
        licenses,
        export_count,
        export_size,
        import_count,
        import_size,
        child_record_count,
        project_count,
        choice_list_count,
        classification_set_count,
        layer_count,
        layer_size,
        report_count,
        report_size,
        changeset_count,
        data_share_count,
        role_count,
        query_log_count,
        android_device_count,
        ios_device_count,
        api_token_count,
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
        data_event_count,
        converted_at,
        conversion_period,
        record_changed_at,
        company_size,
        sign_up_source,
        cache_enabled,
        cache_size,
        intercom_company_id,
        signup_geodata,
        signup_ip,
        signup_latitude,
        signup_longitude,
        signup_country,
        signup_city,
        signup_locality,
        consented_by_id,
        consented_at,
        tier,
        domain,
        saml_enabled,
        multidb_migrated_at,
        saml_timeout,
        saml_issuer,
        sign_up_params
    FROM source
)

SELECT * FROM renamed