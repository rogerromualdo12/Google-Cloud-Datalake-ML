WITH sf_accounts AS (
    SELECT
        acc.Fulcrum_ID__c AS Fulcrum_ID,
        acc.Name AS Fulcrum_Account_Name,
        acc.X18_Digit_Account_ID__c AS X18_Digit_Account_ID__c,
        acc.Fulcrum_Account__c AS Fulcrum_Account_Link,
        acc.Auto_Suspend_Enabled__c AS Auto_Suspend_Enabled,
        acc.Suspended__c AS Suspended_Date,
        acc.Max_Users__c AS Max_Users,
        acc.Min_Users__c AS Min_Users,
        acc.Included_Users__c AS Included_Users,
        acc.Active_Users__c AS Active_Users,
        acc.Trial_End_Date__c AS Trial_End_Date,
        acc.Record_Count__c AS Records,
        acc.Membership_Count__c AS Members,
        acc.Active_Device_Count__c AS Active_Devices,
        acc.Data_Usage__c AS Media_Data_Usage,
        acc.Layer_Size__c AS Layer_Size,
        acc.Database_Size__c AS Database_Size,
        null AS Cache_Size,
        acc.Sign_Up_Source__c AS Sign_Up_Source,
        acc.Signup_Date__c AS Signup_Date,
        acc.Converted_at__c AS Initial_Purchase_Date
    FROM {{ ref('salesforce_account') }} AS acc
),

ifs AS (
    SELECT DISTINCT resource_id
    FROM {{ ref('fulcrum_ita_form_stats') }}
),

projects AS (
    SELECT DISTINCT owner_id
    FROM {{ ref('fulcrum_projects') }}
),

fgroups AS (
    SELECT
        org_id,
        count(*) AS group_cnt
    FROM {{ ref('s_fulcrum_app_groups') }}
    GROUP BY 1
),

forms AS (
    SELECT DISTINCT
        status_field,
        owner_id
    FROM {{ ref('fulcrum_forms') }}
    WHERE status_field = "{}"
),

forms_count AS (
    SELECT
        org_resource_id,
        sum(CASE
            WHEN cast(record_changed_at AS DATE) >= date_sub(current_date(), INTERVAL 30 DAY)
                THEN 1
            ELSE 0
        END) AS FormsActivityLast30Days,
        count(*) AS FormsCount
    FROM {{ ref('rpt_forms') }}
    GROUP BY 1
),

appcues AS (
    SELECT
        user_org_id,
        sum(if(user_flag_feature_service_layers_enabled, 1, 0)) AS feature_services
    FROM {{ ref('fulcrum_app_flow_completed_appcues') }}
    GROUP BY 1
),

members_count AS (
    SELECT
        org_resource_id,
        count(*) AS MembersSignInLast30Days
    FROM {{ ref('rpt_members') }}
    WHERE cast(last_sign_in_at AS DATE) >= date_sub(current_date(), INTERVAL 30 DAY)
    GROUP BY 1
),

app_syncs AS (
    SELECT
        owner_id,
        count(DISTINCT device_id) AS DevicesSyncLast30Days
    FROM {{ ref('fulcrum_organization_mobile_device_registrations') }}
    WHERE date(updated_at) >= date_add(current_date(), INTERVAL -30 DAY)
    GROUP BY 1
),

members_sync_count AS (
    SELECT
        registrations.owner_id,
        count(DISTINCT memberships.user_id) AS MembersSyncLast30Days
    FROM {{ ref('fulcrum_memberships') }} AS memberships
    INNER JOIN {{ ref('fulcrum_organization_mobile_device_registrations') }} AS registrations
        ON memberships.user_id = registrations.user_id
    WHERE date(registrations.updated_at) >= date_add(current_date(), INTERVAL -30 DAY)
    GROUP BY 1
),

workflows_cnt AS (
    SELECT
        owner_id,
        count(*) AS workflows_count
    FROM {{ source('sni_fulcrum', 'workflows') }}
    GROUP BY 1
),

orgs AS (
    SELECT
        orgs.resource_id,
        fc.FormsActivityLast30Days,
        fc.FormsCount,
        memb.MembersSignInLast30Days,
        memb_s.MembersSyncLast30Days,
        app_s.DevicesSyncLast30Days,
        if(orgs.api_token_count > 0, "yes", "no") AS API_Tokens,
        if(orgs.data_event_count > 0, "yes", "no") AS Data_Events,
        if(orgs.repeatable_count > 0, "yes", "no") AS Repeatables,
        if(orgs.report_count > 0, "yes", "no") AS Reports,
        if(workf.workflows_count > 0, "yes", "no") AS Workflows,
        if(coalesce(gt.LineString, null, 0) > 0, "yes", "no") AS Lines,
        CASE
            WHEN
                if(coalesce(gt.LineString, null, 0) > 0, true, false)
                OR if(coalesce(gt.MultiLineString, null, 0) > 0, true, false)
                OR if(coalesce(gt.Polygon, null, 0) > 0, true, false)
                OR if(coalesce(gt.MultiPolygon, null, 0) > 0, true, false)
                THEN "yes"
            ELSE "no"
        END AS Lines_Polygons,
        if(subs.shared_views_enabled = true, "yes", "no") AS Data_Views,
        if(ifs.resource_id IS NOT null, "yes", "no") AS Issues_Tasks,
        if(orgs.record_link_field_count > 0, "yes", "no") AS Record_Assignments,
        if(proj.owner_id IS NOT null, "yes", "no") AS Projects,
        if(coalesce(grps.group_cnt, null, 0) > 0, "yes", "no") AS Ful_Groups,
        if(forms.owner_id IS NOT null, "yes", "no") AS Status_Field,
        if(coalesce(appc.feature_services, null, 0) > 0, "yes", "no") AS FeatureServices
    FROM {{ ref('fulcrum_organizations') }} AS orgs
    LEFT JOIN {{ ref('fulcrum_subscriptions') }} AS subs
        ON orgs.id = subs.owner_id
    LEFT JOIN s_fulcrum_app.vw_geometry_types_summary AS gt
        ON orgs.resource_id = gt.organization_id
    LEFT JOIN ifs
        ON orgs.resource_id = ifs.resource_id
    LEFT JOIN projects AS proj
        ON orgs.id = proj.owner_id
    LEFT JOIN fgroups AS grps
        ON orgs.resource_id = grps.org_id
    LEFT JOIN forms
        ON orgs.id = forms.owner_id
    LEFT JOIN appcues AS appc
        ON orgs.resource_id = appc.user_org_id
    LEFT JOIN forms_count AS fc
        ON orgs.resource_id = fc.org_resource_id
    LEFT JOIN members_count AS memb
        ON orgs.resource_id = memb.org_resource_id
    LEFT JOIN members_sync_count AS memb_s
        ON orgs.id = memb_s.owner_id
    LEFT JOIN app_syncs AS app_s
        ON orgs.id = app_s.owner_id
    LEFT JOIN workflows_cnt AS workf
        ON orgs.id = workf.owner_id
)

SELECT
    sf_acc.Fulcrum_ID,
    sf_acc.Fulcrum_Account_Name,
    sf_acc.X18_Digit_Account_ID__c,
    sf_acc.Fulcrum_Account_Link,
    sf_acc.Auto_Suspend_Enabled,
    sf_acc.Suspended_Date,
    sf_acc.Max_Users,
    sf_acc.Min_Users,
    sf_acc.Included_Users,
    sf_acc.Active_Users,
    sf_acc.Trial_End_Date,
    sf_acc.Records,
    sf_acc.Members,
    orgs.MembersSyncLast30Days,
    orgs.MembersSignInLast30Days,
    orgs.FormsCount,
    orgs.FormsActivityLast30Days,
    orgs.DevicesSyncLast30Days,
    sf_acc.Active_Devices,
    sf_acc.Media_Data_Usage,
    sf_acc.Layer_Size,
    sf_acc.Database_Size,
    sf_acc.Cache_Size,
    sf_acc.Sign_Up_Source,
    sf_acc.Signup_Date,
    sf_acc.Initial_Purchase_Date,
    orgs.resource_id,
    orgs.API_Tokens,
    orgs.Data_Events,
    orgs.Repeatables,
    orgs.Reports,
    orgs.Workflows,
    orgs.Lines,
    orgs.Lines_Polygons,
    orgs.Data_Views,
    orgs.Issues_Tasks,
    orgs.Record_Assignments,
    orgs.Projects,
    orgs.Ful_Groups,
    orgs.Status_Field,
    orgs.FeatureServices
FROM orgs AS orgs
LEFT JOIN sf_accounts AS sf_acc
    ON orgs.resource_id = sf_acc.Fulcrum_ID
