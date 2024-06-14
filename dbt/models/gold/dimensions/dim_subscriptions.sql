WITH fulcrum_stripe_customers_dedup AS (
    SELECT DISTINCT
        organization_id,
        customer_id
    FROM {{ ref('fulcrum_stripe_customers') }}
)

SELECT
    subs.id AS str_subscription_key,
    subs.customer AS str_customer_key,
    subs.collection_method,
    subs.currency,
    subs.plan_active,
    subs.plan_interval,
    subs.status,
    prods_0.name AS plan_0_name,
    prods_1.name AS plan_1_name,
    prods_2.name AS plan_2_name,
    ful_orgs.membership_count,
    ful_orgs.active_device_count,
    ful_orgs.form_count,
    ful_orgs.record_count,
    ful_orgs.created_at AS signed_up_date,
    subs.trial_end AS trial_end_date,
    ful_subs.media_data_usage,
    ful_subs.form_scripts_enabled,
    CONCAT('https://dashboard.stripe.com/subscriptions/', subs.id) AS str_subscription_link
FROM {{ ref('stripe_subscriptions') }} AS subs
LEFT JOIN {{ ref('stripe_products') }} AS prods_0
    ON subs.items_data_0_plan_product = prods_0.id
LEFT JOIN {{ ref('stripe_products') }} AS prods_1
    ON subs.items_data_1_plan_product = prods_1.id
LEFT JOIN {{ ref('stripe_products') }} AS prods_2
    ON subs.items_data_2_plan_product = prods_2.id
INNER JOIN {{ ref('stripe_customers') }} AS cust
    ON subs.customer = cust.id
INNER JOIN fulcrum_stripe_customers_dedup AS dedup
    ON cust.id = dedup.customer_id
INNER JOIN {{ ref('fulcrum_organizations') }} AS ful_orgs
    ON dedup.organization_id = ful_orgs.id
INNER JOIN {{ ref('fulcrum_subscriptions') }} AS ful_subs
    ON ful_orgs.id = ful_subs.owner_id
