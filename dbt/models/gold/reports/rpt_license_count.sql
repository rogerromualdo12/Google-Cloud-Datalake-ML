WITH subs AS (
    SELECT
        c.metadata_organization_id AS Fulcrum_Org_ID,
        s.id AS subs_id,
        ss.status,
        a.Top_Parent_Account_ID__c AS SFDC_Top_Parent_AccountID,
        a.Name AS SFDC_Account_Name,
        u1.First_and_Last_Name__c AS SFDC_Account_Owner,
        a.Owner_s_Manager__c AS SFDC_Sales_Director,
        a.Next_Billing_Date__c AS Next_Billing_date,
        a.X18_Digit_Account_ID__c AS X18_Digit_Account_ID__c,
        o.membership_count,
        concat("https://web.fulcrumapp.com/admin/customers/", c.metadata_organization_id) AS Fulcrum_URL,
        concat("https://dashboard.stripe.com/customers/", c.id) AS stripe_URL,
        coalesce(c.name, c.description, c.name) AS cust_name,
        concat(substr(s.run_date, 1, 4), "-", substr(s.run_date, 5, 2)) AS period,
        CASE
            WHEN sni_stripe.isBasePrice_(s.items_data_0_price_id) IS NOT null THEN s.items_data_0_quantity
            WHEN sni_stripe.isBasePrice_(s.items_data_1_price_id) IS NOT null THEN s.items_data_1_quantity
            WHEN sni_stripe.isBasePrice_(s.items_data_2_price_id) IS NOT null THEN s.items_data_2_quantity
            ELSE 0
        END AS qty,
        CASE
            WHEN
                sni_stripe.isBasePrice_(ss.items_data_0_price_id) IS NOT null
                THEN ss.items_data_0_plan_product
            WHEN
                sni_stripe.isBasePrice_(ss.items_data_1_price_id) IS NOT null
                THEN ss.items_data_1_plan_product
            WHEN
                sni_stripe.isBasePrice_(ss.items_data_2_price_id) IS NOT null
                THEN ss.items_data_2_plan_product
        END AS base_plan,
        CASE
            WHEN sni_stripe.isBasePrice_(ss.items_data_0_price_id) IS NOT null THEN ss.items_data_0_quantity
            WHEN sni_stripe.isBasePrice_(ss.items_data_1_price_id) IS NOT null THEN ss.items_data_1_quantity
            WHEN sni_stripe.isBasePrice_(ss.items_data_2_price_id) IS NOT null THEN ss.items_data_2_quantity
            ELSE 0
        END AS licenses_count,
        concat(substr(s.run_date, 1, 4), "-", substr(s.run_date, 5, 2), "-", substr(s.run_date, 7, 2))
            AS run_date
    FROM sni_stripe_history.subscriptions AS s
    INNER JOIN sni_stripe.customers AS c
        ON s.customer = c.id
    LEFT JOIN sni_salesforce.Account AS a
        ON c.metadata_organization_id = a.Fulcrum_ID__c
    LEFT JOIN sni_salesforce.User AS u1
        ON a.OwnerId = u1.Id
    LEFT JOIN sni_salesforce.User AS u2
        ON a.Owner_s_Manager__c = u2.Id
    INNER JOIN sni_stripe.subscriptions AS ss
        ON s.id = ss.id
    INNER JOIN sni_fulcrum.organizations AS o
        ON c.metadata_organization_id = o.resource_id
    ORDER BY s.created
),

dates AS (
    SELECT DISTINCT substr(cast(date_trunc(curr_date, MONTH) AS string), 1, 10) AS init_day
    FROM unnest(generate_date_array(date_add(current_date(), INTERVAL -18 MONTH), current_date())) AS curr_date
)

SELECT *
FROM
    (
        SELECT
            subs.Fulcrum_Org_ID,
            subs.Fulcrum_URL,
            subs.subs_id,
            subs.stripe_URL,
            subs.status,
            subs.cust_name,
            subs.SFDC_Account_Owner,
            subs.X18_Digit_Account_ID__c,
            subs.SFDC_Sales_Director,
            subs.Next_Billing_date,
            subs.period,
            subs.base_plan,
            pro.name,
            subs.membership_count,
            subs.licenses_count,
            cast(avg(subs.qty) AS int64) AS qtty
        FROM subs
        INNER JOIN sni_stripe.products AS pro
            ON subs.base_plan = pro.id
        INNER JOIN dates AS dt
            ON subs.run_date = dt.init_day
        {{ dbt_utils.group_by(n=15) }}
    )
PIVOT
(
    sum(qtty)
    FOR period IN (
        "2022-01",
        "2022-02",
        "2022-03",
        "2022-04",
        "2022-05",
        "2022-06",
        "2022-07",
        "2022-08",
        "2022-09",
        "2022-10",
        "2022-11",
        "2022-12",
        "2023-01",
        "2023-02",
        "2023-03",
        "2023-04",
        "2023-05",
        "2023-06",
        "2023-07",
        "2023-08",
        "2023-09",
        "2023-10",
        "2023-11",
        "2023-12",
        "2024-01",
        "2024-02",
        "2024-03",
        "2024-04",
        "2024-05",
        "2024-06",
        "2024-07",
        "2024-08",
        "2024-09",
        "2024-10",
        "2024-11"
    )
)
