WITH fulcrum_stripe_customers_dedup AS (
    SELECT DISTINCT
        organization_id,
        customer_id
    FROM {{ ref('fulcrum_stripe_customers') }}
)

SELECT
    ful_orgs.resource_id AS ful_customer_key,
    dedup.customer_id AS str_customer_key,
    ful_orgs.membership_count,
    ful_orgs.active_device_count,
    ful_orgs.form_count,
    ful_orgs.record_count,
    mrr.mrr
FROM {{ ref('fulcrum_organizations') }} AS ful_orgs
LEFT JOIN fulcrum_stripe_customers_dedup AS dedup
    ON ful_orgs.id = dedup.organization_id
INNER JOIN {{ ref('stripe_customers') }} AS str_custs
    ON dedup.customer_id = str_custs.id
LEFT JOIN {{ ref('rpt_stripe_mrr') }} AS mrr
    ON str_custs.id = mrr.customer_id
