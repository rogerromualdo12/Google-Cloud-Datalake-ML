WITH fulcrum_stripe_customers_dedup AS (
    SELECT DISTINCT
        organization_id,
        customer_id
    FROM {{ ref('fulcrum_stripe_customers') }}
),

invoices AS (
    SELECT
        inv.customer,
        orgs.resource_id,
        inv.amount_paid,
        format_timestamp("%Y-%m", timestamp_seconds(cast(inv.created AS int))) AS date_created
    FROM sni_stripe.invoices_daily AS inv
    LEFT JOIN fulcrum_stripe_customers_dedup AS map
        ON inv.customer = map.customer_id
    LEFT JOIN sni_fulcrum.organizations AS orgs
        ON map.organization_id = orgs.id
    WHERE inv.paid = true
)

SELECT *
FROM invoices
PIVOT (
    sum(
        amount_paid) FOR date_created IN (
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
        "2023-01", "2023-02", "2023-03", "2023-04", "2023-05", "2023-06", "2023-07", "2023-08", "2023-09", "2023-10"
    )
)
