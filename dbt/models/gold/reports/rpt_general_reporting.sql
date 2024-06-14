WITH fulcrum_reporting AS (
    SELECT
        orgs.id AS org_id,
        orgs.resource_id AS Fulcrum_ID,
        orgs.membership_count AS Members,
        orgs.active_device_count AS Active_Devices,
        orgs.form_count AS Forms,
        orgs.record_count AS Records,
        orgs.sign_up_source AS sign_up_source,
        subs.media_data_usage AS Media_Usage,
        orgs.created_at AS Signed_Up_Date,
        orgs.converted_at AS Converted_At,
        subs.form_scripts_enabled AS Allowed_Apps,
        orgs.customer_name AS organization_name,
        CONCAT('https://web.fulcrumapp.com/admin/customers/', orgs.resource_id) AS Fulcrum_Account_Link
    FROM {{ ref('fulcrum_organizations') }} AS orgs
    INNER JOIN {{ ref('fulcrum_subscriptions') }} AS subs
        ON orgs.id = subs.owner_id
),

stripe_reporting AS (
    SELECT
        cust.metadata_organization_id,
        cust.id AS Customer_ID,
        cust.email AS Customer_email,
        prod.name AS Plan,
        subs.items_data_0_quantity AS Licence_count,
        subs.status AS plan_status,
        subs.trial_end AS Trial_End_Date,
        subs.items_data_0_created AS Subcription_Created,
        subs.created AS Created_Subcription,
        mrr.mrr,
        CONCAT('https://dashboard.stripe.com/customers/', cust.id) AS Subscription_Link,
        (
            COALESCE(subs.items_data_0_plan_amount, 0) * COALESCE(subs.items_data_0_quantity, 0)
            + COALESCE(subs.items_data_1_plan_amount, 0) * COALESCE(subs.items_data_1_quantity, 0)
            + COALESCE(subs.items_data_2_plan_amount, 0) * COALESCE(subs.items_data_2_quantity, 0)
        )
        / 100 AS Price,
        CASE
            WHEN
                (subs.items_data_0_plan_interval = 'month' AND subs.items_data_0_plan_interval_count = 1)
                THEN 'monthly'
            WHEN
                (subs.items_data_0_plan_interval = 'month' AND subs.items_data_0_plan_interval_count = 3)
                THEN 'quarterly'
            WHEN
                (subs.items_data_0_plan_interval = 'month' AND subs.items_data_0_plan_interval_count = 6)
                THEN 'semiannualy'
            WHEN
                (subs.items_data_0_plan_interval = 'year' AND subs.items_data_0_plan_interval_count = 1) THEN 'annualy'
            ELSE
                ''
        END
            AS Billing_Frequency
    FROM {{ ref('stripe_customers') }} AS cust
    LEFT JOIN {{ ref('stripe_subscriptions') }} AS subs
        ON cust.id = subs.customer
    LEFT JOIN {{ ref('stripe_prices') }} AS pric
        ON subs.items_data_0_plan_id = pric.id
    LEFT JOIN {{ ref('stripe_products') }} AS prod
        ON subs.items_data_0_plan_product = prod.id
    LEFT JOIN {{ ref('rpt_stripe_mrr') }} AS mrr
        ON cust.id = mrr.customer_id
    WHERE
        prod.name != 'Developer Pack'
        AND subs.status = 'active'
),

salesfore_opportunities AS (
    SELECT
        accountid,
        subscription_end_date__c,
        opportunity_term__c,
        IsCreatedByStripe__c,
        Self_Serve__c,
        ROW_NUMBER() OVER (PARTITION BY accountid ORDER BY subscription_end_date__c DESC) AS rn
    FROM {{ ref('salesforce_opportunity') }}
),

salesforce_reporting AS (
    SELECT
        acc.fulcrum_id__c,
        acc.x18_digit_account_id__c AS x18_char_account_id,
        acc.name AS account_name,
        accn.name AS top_parent_account,
        sfuser.id AS userid,
        sfuser.name AS account_owner,
        sfuser.firstname AS firstname,
        sfuser.lastname AS lastname,
        acc.owner_s_manager__c AS account_owners_manager,
        opps.opportunity_term__c AS subscription_term,
        opps.IsCreatedByStripe__c AS is_created_by_stripe,
        opps.Self_Serve__c AS self_serve,
        acc.accounttier__c AS account_tier,
        acc.zoominfo_industry__c AS master_field_zoominfo_industry,
        acc.account_type__c AS account_type,
        acc.billing_country__c AS billing_country,
        CONCAT('https://sn1.lightning.force.com/lightning/r/account/', acc.x18_digit_account_id__c, '/view')
            AS sfdc_account_url,
        MAX(opps.subscription_end_date__c) AS subscription_end_date
    FROM {{ ref('salesforce_account') }} AS acc
    INNER JOIN {{ ref('salesforce_account') }} AS accn
        ON acc.Top_Parent_Account_ID__c = accn.X18_Digit_Account_ID__c
    INNER JOIN {{ ref('salesforce_user') }} AS sfuser
        ON acc.OwnerId = sfuser.Id
    INNER JOIN salesfore_opportunities AS opps
        ON
            acc.id = opps.AccountId
            AND opps.rn = 1
    {{ dbt_utils.group_by(n=17) }}
),

user_recs AS (
    SELECT
        m.user_id,
        COUNT(m.id) AS recs
    FROM {{ ref('fulcrum_memberships') }} AS m
    INNER JOIN {{ ref('fulcrum_organizations') }} AS o
        ON m.organization_id = o.id
    WHERE o.converted_at IS NOT NULL
    GROUP BY 1
),

existing_users AS (
    SELECT
        u.user_id,
        COALESCE(q.recs, 0) AS converted_org_count
    FROM {{ ref('fulcrum_users') }} AS u
    LEFT JOIN user_recs AS q
        ON u.user_id = q.user_id
),

existing_users_orgs AS (
    SELECT DISTINCT
        o.id,
        o.resource_id
    FROM {{ ref('fulcrum_organizations') }} AS o
    INNER JOIN {{ ref('fulcrum_memberships') }} AS m
        ON o.id = m.organization_id
    INNER JOIN {{ ref('fulcrum_roles') }} AS r
        ON m.role_id = r.id
    INNER JOIN existing_users AS u
        ON m.user_id = u.user_id
    WHERE
        LOWER(r.name) = 'owner'
        AND (
            (u.converted_org_count > 1 AND o.converted_at IS NOT NULL)
            OR (u.converted_org_count > 0 AND o.converted_at IS NULL)
        )
)

SELECT
    fr.org_id,
    fr.fulcrum_id,
    fr.organization_name,
    fr.members,
    fr.active_devices,
    fr.sign_up_source,
    fr.forms,
    fr.records,
    fr.media_usage,
    fr.signed_up_date,
    fr.converted_at,
    fr.allowed_apps,
    sr.customer_id,
    sr.customer_email,
    sr.subscription_link,
    sr.plan,
    sr.trial_end_date,
    sr.subcription_created,
    sr.price,
    sr.licence_count,
    sr.mrr,
    sr.billing_frequency,
    sr.plan_status,
    sr.created_subcription,
    sfr.x18_char_account_id,
    sfr.sfdc_account_url,
    sfr.account_name,
    sfr.top_parent_account,
    sfr.userid,
    sfr.account_owner,
    sfr.firstname,
    sfr.lastname,
    sfr.account_owners_manager,
    sfr.account_tier,
    sfr.master_field_zoominfo_industry,
    sfr.account_type,
    sfr.billing_country,
    sfr.subscription_end_date,
    sfr.subscription_term,
    sfr.is_created_by_stripe,
    sfr.self_serve,
    cr.last_month AS last_month_revenue,
    IF(ex.resource_id IS NULL, FALSE, TRUE) AS from_existing_user
FROM
    fulcrum_reporting AS fr
LEFT JOIN stripe_reporting AS sr
    ON fr.Fulcrum_ID = sr.metadata_organization_id
INNER JOIN salesforce_reporting AS sfr
    ON fr.Fulcrum_ID = sfr.Fulcrum_ID__c
LEFT JOIN sni_netsuite.vw_customer_revenue AS cr
    ON fr.Fulcrum_ID = cr.fulcrum_id
LEFT JOIN existing_users_orgs AS ex
    ON fr.org_id = ex.id
