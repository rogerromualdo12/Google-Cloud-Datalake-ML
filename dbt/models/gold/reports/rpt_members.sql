WITH users AS (
    SELECT
        user_id,
        first_name,
        last_name,
        phone,
        last_synced_at,
        email,
        last_sign_in_at
    FROM {{ ref('fulcrum_users') }}
),

memberships AS (
    SELECT
        user_id,
        organization_id,
        role_id
    FROM {{ ref('fulcrum_memberships') }}
),

organizations AS (
    SELECT
        id AS org_id,
        resource_id AS org_resource_id
    FROM {{ ref('fulcrum_organizations') }}
),

roles AS (
    SELECT
        id AS role_id,
        name AS role_name
    FROM {{ ref('fulcrum_roles') }}
),

sf_accounts AS (
    SELECT
        Fulcrum_ID__c AS Fulcrum_ID,
        X18_Digit_Account_ID__c AS X18_Digit_Account_ID
    FROM {{ ref('salesforce_account') }}
)

SELECT
    u.user_id,
    o.org_resource_id,
    o.org_id,
    sf.X18_Digit_Account_ID,
    u.first_name,
    u.last_name,
    u.phone,
    u.email,
    r.role_name,
    u.last_synced_at,
    u.last_sign_in_at
FROM users AS u
INNER JOIN memberships AS m
    ON u.user_id = m.user_id
INNER JOIN organizations AS o
    ON m.organization_id = o.org_id
LEFT JOIN roles AS r
    ON m.role_id = r.role_id
LEFT JOIN sf_accounts AS sf
    ON o.org_resource_id = sf.Fulcrum_ID
