WITH sf_accounts AS (
    SELECT
        Fulcrum_ID__c AS Fulcrum_ID,
        X18_Digit_Account_ID__c AS X18_Digit_Account_ID,
        Fulcrum_Account__c AS Fulcrum_Account,
        Name AS Fulcrum_Name
    FROM {{ ref('salesforce_account') }}
    WHERE
        Fulcrum_ID__c IS NOT NULL
        AND Id NOT IN (
            "0018W00002KJholQAD",
            "0011I00000RggB2QAJ",
            "0011I00001K65NeQAJ",
            "001Rk000009Ff4XIAS"
        )
),

users AS (
    SELECT
        user_id,
        first_name,
        last_name,
        phone,
        email,
        last_sign_in_at
    FROM {{ ref('fulcrum_users') }}
),

syncs AS (
    SELECT
        identifier,
        organization_id,
        loaded_at AS last_synced_at,
        ROW_NUMBER() OVER (PARTITION BY identifier ORDER BY loaded_at DESC) AS rn
    FROM {{ ref('s_fulcrum_app_organization_device_sync') }}
),

devices AS (
    SELECT
        id,
        resource_id,
        owner_id AS user_id,
        identifier,
        platform,
        platform_version,
        manufacturer,
        model,
        application_version,
        created_at AS device_created_as
    FROM {{ ref('fulcrum_organization_mobile_devices') }}
)

SELECT
    d.id AS device_id,
    u.first_name,
    u.last_name,
    u.phone,
    u.email,
    d.resource_id,
    sf.Fulcrum_ID,
    sf.X18_Digit_Account_ID,
    sf.Fulcrum_Account,
    sf.Fulcrum_Name,
    d.user_id,
    d.identifier,
    d.platform,
    d.platform_version,
    d.manufacturer,
    d.model,
    d.application_version,
    d.device_created_as,
    s.last_synced_at
FROM devices AS d
INNER JOIN syncs AS s
    ON
        d.identifier = s.identifier
        AND s.rn = 1
LEFT JOIN users AS u
    ON d.user_id = u.user_id
LEFT JOIN sf_accounts AS sf
    ON s.organization_id = sf.Fulcrum_ID
