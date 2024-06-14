WITH hist_prods AS (
    SELECT
        id,
        name,
        run_date
    FROM sni_stripe_history.products
    WHERE name IN (
        'Enterprise',
        'Professional',
        'Professional 2019',
        'Essentials',
        'Essentials 2019',
        'Starter'
    )
),

price_base AS (
    SELECT
        subs.id AS subs_id,
        subs.customer AS customer,
        concat(substr(subs.run_date, 1, 4), '-', substr(subs.run_date, 5, 2)) AS run_date,
        CASE
            WHEN p0.name IS NOT NULL THEN p0.name
            WHEN p1.name IS NOT NULL THEN p1.name
            WHEN p2.name IS NOT NULL THEN p2.name
        END AS plan_name,
        CASE
            WHEN p0.name IS NOT NULL THEN subs.items_data_0_quantity
            WHEN p1.name IS NOT NULL THEN subs.items_data_1_quantity
            WHEN p2.name IS NOT NULL THEN subs.items_data_2_quantity
        END AS quantity,
        CASE
            WHEN p0.name IS NOT NULL THEN subs.items_data_0_plan_amount / 100
            WHEN p1.name IS NOT NULL THEN subs.items_data_1_plan_amount / 100
            WHEN p2.name IS NOT NULL THEN subs.items_data_2_plan_amount / 100
        END AS amount
    FROM sni_stripe_history.subscriptions AS subs
    LEFT JOIN hist_prods AS p0
        ON
            subs.items_data_0_plan_product = p0.id
            AND substr(subs.run_date, 1, 8) = substr(p0.run_date, 1, 8)
    LEFT JOIN hist_prods AS p1
        ON
            subs.items_data_1_plan_product = p1.id
            AND substr(subs.run_date, 1, 8) = substr(p1.run_date, 1, 8)
    LEFT JOIN hist_prods AS p2
        ON
            subs.items_data_2_plan_product = p2.id
            AND substr(subs.run_date, 1, 8) = substr(p2.run_date, 1, 8)
    WHERE
        p0.name IS NOT NULL
        OR p1.name IS NOT NULL
        OR p2.name IS NOT NULL
),

dates AS (
    SELECT DISTINCT substr(cast(date_trunc(curr_date, MONTH) AS string), 1, 7) AS init_day
    FROM unnest(generate_date_array(date_add(current_date(), INTERVAL -18 MONTH), current_date())) AS curr_date
),

final_base AS (
    SELECT
        c.metadata_organization_id AS Fulcrum_Org_ID,
        s.subs_id AS subs_id,
        u1.First_and_Last_Name__c AS SFDC_Account_Owner,
        a.Owner_s_Manager__c AS SFDC_Sales_Director,
        a.Next_Billing_Date__c AS Next_Billing_date,
        a.X18_Digit_Account_ID__c AS X18_Digit_Account_ID__c,
        s.customer AS customer,
        s.run_date AS period,
        s.plan_name AS plan_name,
        s.amount AS amount,
        concat('https://web.fulcrumapp.com/admin/customers/', c.metadata_organization_id) AS Fulcrum_URL,
        concat('https://dashboard.stripe.com/customers/', c.id) AS stripe_URL,
        coalesce(c.name, c.description, c.name) AS cust_name
    FROM price_base AS s
    INNER JOIN sni_stripe.customers AS c
        ON s.customer = c.id
    LEFT JOIN sni_salesforce.Account AS a
        ON c.metadata_organization_id = a.Fulcrum_ID__c
    LEFT JOIN sni_salesforce.User AS u1
        ON a.OwnerId = u1.Id
    LEFT JOIN sni_salesforce.User AS u2
        ON a.Owner_s_Manager__c = u2.Id
    INNER JOIN sni_stripe.subscriptions AS ss
        ON s.subs_id = ss.id
    INNER JOIN sni_fulcrum.organizations AS o
        ON c.metadata_organization_id = o.resource_id
    INNER JOIN dates AS dt
        ON s.run_date = dt.init_day
)

SELECT *
FROM (
    SELECT
        Fulcrum_Org_ID,
        Fulcrum_URL,
        subs_id,
        stripe_URL,
        cust_name,
        SFDC_Account_Owner,
        SFDC_Sales_Director,
        Next_Billing_date,
        X18_Digit_Account_ID__c,
        customer,
        period,
        plan_name,
        cast(avg(amount) AS int64) AS amount
    FROM final_base
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
)
PIVOT
(
    sum(amount)
    FOR period IN (
        '2022-01',
        '2022-02',
        '2022-03',
        '2022-04',
        '2022-05',
        '2022-06',
        '2022-07',
        '2022-08',
        '2022-09',
        '2022-10',
        '2022-11',
        '2022-12',
        '2023-01',
        '2023-02',
        '2023-03',
        '2023-04',
        '2023-05',
        '2023-06',
        '2023-07',
        '2023-08',
        '2023-09',
        '2023-10',
        '2023-11',
        '2023-12',
        '2024-01',
        '2024-02',
        '2024-03',
        '2024-04',
        '2024-05',
        '2024-06',
        '2024-07',
        '2024-08',
        '2024-09',
        '2024-10',
        '2024-11'
    )
)
