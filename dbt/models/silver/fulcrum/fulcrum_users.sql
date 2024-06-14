WITH source AS (
    SELECT * FROM {{ source('sni_fulcrum', 'users') }}
),

renamed AS (
    SELECT
        id AS user_id,
        resource_id,
        api_usage,
        first_name,
        last_name,
        phone,
        is_notification_enabled,
        disabled_at,
        sign_up_account_type,
        sign_up_ip,
        time_zone,
        accepted_terms_at,
        gravatar_email,
        last_user_agent,
        last_synced_at,
        last_sync_device,
        last_sync_ip,
        email,
        reset_password_sent_at,
        remember_created_at,
        sign_in_count,
        current_sign_in_at,
        last_sign_in_at,
        current_sign_in_ip,
        last_sign_in_ip,
        confirmed_at,
        confirmation_sent_at,
        followup_sent_at,
        welcome_sent_at,
        created_at,
        updated_at,
        trial_started_at,
        second_followup_sent_at,
        trial_ending_sent_at,
        dismissed_helpers,
        notes,
        intercom_user_id,
        owner_id,
        managed_user_name,
        managed_email,
        completed_onboarding,
        user_type

    FROM source
)

SELECT * FROM renamed
