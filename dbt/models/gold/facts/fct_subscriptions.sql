WITH all_prods AS (
    SELECT
        subs.id,
        prods.name AS prod_name,
        subs.items_data_0_quantity AS quantity,
        subs.items_data_0_plan_amount / 100 AS amount
    FROM {{ ref("stripe_subscriptions") }} AS subs
    LEFT JOIN sni_stripe.products AS prods
        ON subs.items_data_0_plan_product = prods.id
    WHERE subs.items_data_0_plan_product IS NOT null
    UNION ALL
    SELECT
        subs.id,
        prods.name AS prod_name,
        subs.items_data_1_quantity AS quantity,
        subs.items_data_1_plan_amount / 100 AS amount
    FROM {{ ref("stripe_subscriptions") }} AS subs
    LEFT JOIN sni_stripe.products AS prods
        ON subs.items_data_1_plan_product = prods.id
    WHERE subs.items_data_1_plan_product IS NOT null
    UNION ALL
    SELECT
        subs.id,
        prods.name AS prod_name,
        subs.items_data_2_quantity AS quantity,
        subs.items_data_2_plan_amount / 100 AS amount
    FROM {{ ref("stripe_subscriptions") }} AS subs
    LEFT JOIN sni_stripe.products AS prods
        ON subs.items_data_2_plan_product = prods.id
    WHERE subs.items_data_2_plan_product IS NOT null
),

licenses_calculations AS (
    SELECT
        id,
        sum(
            if(
                prod_name IN (
                    'Enterprise',
                    'Professional',
                    'Professional 2019',
                    'Essentials',
                    'Essentials 2019',
                    'Starter'
                ),
                quantity,
                0
            )
        ) AS paid_licenses,
        sum(
            if(
                prod_name IN (
                    'Enterprise',
                    'Professional',
                    'Professional 2019',
                    'Essentials',
                    'Essentials 2019',
                    'Starter'
                ),
                amount,
                0
            )
        ) AS total_amount,
        sum(
            if(
                prod_name NOT IN (
                    'Developer',
                    'Developer Pack',
                    'Data Block',
                    'Professional Services',
                    'Managed Services',
                    'Professional Service PDF Report Template',
                    'Arcadis - Enterprise + Managed Services',
                    'NYSEG - Managed Services'
                ),
                quantity,
                0
            )
        ) AS total_licenses
    FROM all_prods
    GROUP BY 1
),

stripe_subscriptions AS (
    SELECT
        subs.id AS str_subscription_key,
        subs.customer AS str_customer_key,
        subs.status,
        subs.collection_method,
        cast(licenses.paid_licenses AS int) AS paid_licenses,
        cast(licenses.total_licenses - paid_licenses AS int) AS unpaid_licenses,
        cast(licenses.total_licenses AS int) AS total_licenses,
        licenses.total_amount,
        CASE
            WHEN subs.plan_interval = 'month' THEN 'monthly'
            WHEN subs.items_data_0_plan_interval = 'month' AND subs.items_data_0_plan_interval_count = 1
                THEN 'monthly'
            WHEN subs.items_data_0_plan_interval = 'month' AND subs.items_data_0_plan_interval_count = 3
                THEN 'quarterly'
            WHEN subs.items_data_0_plan_interval = 'month' AND subs.items_data_0_plan_interval_count = 6
                THEN 'biannually'
            WHEN subs.items_data_0_plan_interval = 'year'
                THEN 'annually'
        END AS plan_interval,
        date(subs.current_period_start) AS current_period_start,
        date(subs.current_period_end) AS current_period_end,
        date(subs.created) AS created,
        date(subs.ended_at) AS ended_at
    FROM {{ ref("stripe_subscriptions") }} AS subs
    INNER JOIN licenses_calculations AS licenses
        ON subs.id = licenses.id
),

fulcrum_stripe_customers_dedup AS (
    SELECT DISTINCT
        organization_id,
        customer_id
    FROM {{ ref('fulcrum_stripe_customers') }}
),

fulcrum AS (
    SELECT
        fulcrum_organizations.resource_id AS ful_customer_key,
        fulcrum_stripe_customers_dedup.customer_id AS str_customer_key,
        fulcrum_organizations.industry_name AS industry_name,
        fulcrum_organizations.membership_count AS membership_count,
        fulcrum_organizations.active_device_count AS active_device_count,
        fulcrum_organizations.form_count AS form_count,
        fulcrum_organizations.record_count AS record_count,
        fulcrum_organizations.created_at AS signed_up_date
    FROM {{ ref('fulcrum_organizations') }}
    LEFT JOIN fulcrum_stripe_customers_dedup
        ON fulcrum_organizations.id = fulcrum_stripe_customers_dedup.organization_id
),

fulcrum_subscriptions AS (
    SELECT
        stripe_customer_token AS str_customer_key,
        max_users,
        min_users,
        media_data_usage,
        form_scripts_enabled
    FROM {{ ref('fulcrum_subscriptions') }}
)

SELECT DISTINCT
    fulcrum.ful_customer_key,
    stripe_subscriptions.str_subscription_key,
    stripe_subscriptions.str_customer_key,
    stripe_subscriptions.plan_interval,
    stripe_subscriptions.status,
    stripe_subscriptions.current_period_start,
    stripe_subscriptions.current_period_end,
    stripe_subscriptions.created,
    stripe_subscriptions.ended_at,
    stripe_subscriptions.collection_method,
    stripe_subscriptions.paid_licenses,
    stripe_subscriptions.unpaid_licenses,
    stripe_subscriptions.total_licenses,
    stripe_subscriptions.total_amount,
    mrr.mrr,
    fulcrum.industry_name,
    fulcrum.membership_count,
    fulcrum.active_device_count,
    fulcrum.form_count,
    fulcrum.record_count,
    fulcrum.signed_up_date,
    fulcrum_subscriptions.max_users,
    fulcrum_subscriptions.min_users,
    fulcrum_subscriptions.media_data_usage,
    fulcrum_subscriptions.form_scripts_enabled
FROM stripe_subscriptions
LEFT JOIN fulcrum
    ON stripe_subscriptions.str_customer_key = fulcrum.str_customer_key
LEFT JOIN {{ ref('rpt_stripe_mrr') }} AS mrr
    ON stripe_subscriptions.str_customer_key = mrr.customer_id
LEFT JOIN fulcrum_subscriptions
    ON stripe_subscriptions.str_customer_key = fulcrum_subscriptions.str_customer_key
