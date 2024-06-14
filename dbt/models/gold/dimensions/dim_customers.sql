WITH fulcrum_stripe_customers_dedup AS (
    SELECT DISTINCT
        organization_id,
        customer_id
    FROM {{ ref('fulcrum_stripe_customers') }}
)

SELECT
    str_cust.metadata_organization_id AS ful_customer_key,
    str_cust.id AS str_customer_key,
    ful_orgs.name,
    str_cust.email,
    ful_orgs.locality,
    ful_orgs.region,
    ful_orgs.country,
    ful_orgs.created_by_id,
    ful_orgs.company_size,
    ful_orgs.created_at,
    CONCAT('https://web.fulcrumapp.com/admin/customers/', ful_orgs.resource_id) AS ful_account_link,
    CONCAT('https://dashboard.stripe.com/customers/', str_cust.id) AS str_customer_link
FROM {{ ref('stripe_customers') }} AS str_cust
LEFT JOIN fulcrum_stripe_customers_dedup AS dedup
    ON str_cust.id = dedup.customer_id
LEFT JOIN {{ ref('fulcrum_organizations') }} AS ful_orgs
    ON dedup.organization_id = ful_orgs.id
WHERE ful_orgs.resource_id IS NOT NULL
