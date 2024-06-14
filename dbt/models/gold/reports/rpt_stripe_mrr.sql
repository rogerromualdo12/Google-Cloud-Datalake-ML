WITH stripe_subscriptions AS (
    SELECT
        subs.id,
        cast(json_value(plans.json_data.quantity) AS int) AS quantity,
        cast(json_value(plans.json_data.plan.amount) AS int) AS amount,
        cast(json_value(plans.json_data.plan.interval_count) AS int) AS interval_count,
        json_value(subs.json_data.customer) AS customer_id,
        timestamp_seconds(cast(json_value(subs.json_data.start_date) AS int)) AS start_date,
        timestamp_seconds(cast(json_value(subs.json_data.canceled_at) AS int)) AS canceled_at,
        json_value(subs.json_data.status) AS status,
        json_value(plans.json_data.subscription) AS subscription,
        json_value(plans.json_data.price.id) AS price_id,
        json_value(plans.json_data.plan.interval) AS interval_period,
        json_value(plans.json_data.plan.currency) AS currency
    FROM {{ ref('astripe_subscriptions') }} AS subs
    LEFT JOIN {{ ref('astripe_subscription_items') }} AS plans
        ON subs.id = json_value(plans.json_data.subscription)
),

stripe_mrr_normalization AS (
    SELECT
        id,
        customer_id,
        start_date,
        canceled_at,
        id AS subscription_id,
        status,
        price_id,
        quantity,
        interval_count,
        interval_period,
        currency,
        amount / 100 AS amount,
        CASE
            WHEN date_trunc(start_date, MONTH) != date_trunc(canceled_at, MONTH) THEN 0
            WHEN canceled_at IS null THEN 0
            ELSE 1
        END AS deleted,
        CASE
            WHEN interval_period = "year" THEN ((amount / interval_count) / 12) * quantity
            ELSE (amount / interval_count) * quantity
        END AS monthly_amount
    FROM stripe_subscriptions
    WHERE CASE
        WHEN date_trunc(start_date, MONTH) != date_trunc(canceled_at, MONTH) THEN 0
        WHEN canceled_at IS null THEN 0
        ELSE 1
    END = 0
),



revenue_per_subscription AS (
    SELECT
        customer_id,
        cast(date_trunc(start_date, MONTH) AS date) AS start_date_month,
        cast(date_trunc(canceled_at, MONTH) AS date) AS canceled_at,
        status,
        sum(monthly_amount) AS monthly_amount,
        sum(monthly_amount) / 100 AS monthly_amount_after_discount
    FROM
        stripe_mrr_normalization
    GROUP BY
        customer_id,
        start_date_month,
        canceled_at,
        status
),

active_subscriptions AS (
    SELECT
        customer_id,
        max(status) AS status
    FROM
        revenue_per_subscription
    WHERE
        status != "canceled"
    GROUP BY
        customer_id
),

cancelled_subscriptions AS (
    SELECT
        customer_id,
        max(canceled_at) AS canceled_at,
        max(status) AS status
    FROM
        revenue_per_subscription
    WHERE
        status = "canceled"
    GROUP BY
        customer_id
),


stripe_mrr_active_subscriptions AS (
    SELECT
        r.customer_id,
        r.start_date_month,
        cast(round(sum(r.monthly_amount_after_discount), 0) AS int) AS monthly_amount_after_discount,
        coalesce(s.status, c.status) AS status,
        CASE WHEN coalesce(s.status, c.status) = "canceled" THEN c.canceled_at
        END AS canceled_at
    FROM revenue_per_subscription AS r
    LEFT JOIN active_subscriptions AS s ON r.customer_id = s.customer_id
    LEFT JOIN cancelled_subscriptions AS c ON r.customer_id = c.customer_id
    GROUP BY
        r.customer_id,
        status,
        r.status,
        r.start_date_month,
        canceled_at
),


time_series AS (
    SELECT month
    FROM unnest(generate_date_array(date_trunc("2021-01-01", MONTH), current_date, INTERVAL 1 MONTH)) AS month
),

time_series_customer AS (
    SELECT *
    FROM
        (
            SELECT DISTINCT
                t.month,
                (s.customer_id) AS customer_id
            FROM stripe_mrr_active_subscriptions AS s
            CROSS JOIN time_series AS t
            ORDER BY s.customer_id, t.month
        )
),

time_series_revenue AS (
    SELECT
        c.customer_id,
        c.month,
        r.start_date_month,
        r.monthly_amount_after_discount,
        first_value(r.canceled_at IGNORE NULLS) OVER (PARTITION BY c.customer_id ORDER BY c.month ASC) AS canceled_at,
        first_value(r.status IGNORE NULLS) OVER (PARTITION BY c.customer_id ORDER BY c.month ASC) AS status,
        last_value(r.monthly_amount_after_discount IGNORE NULLS)
            OVER (PARTITION BY c.customer_id ORDER BY c.month ASC)
            AS mrr
    FROM time_series_customer AS c
    LEFT JOIN stripe_mrr_active_subscriptions AS r
        ON
            c.customer_id = r.customer_id
            AND c.month = r.start_date_month
    ORDER BY c.customer_id ASC, c.month ASC
)

SELECT
    *,
    CASE
        WHEN mrr - lag(mrr) OVER (PARTITION BY customer_id ORDER BY month ASC) IS null THEN mrr
        ELSE mrr - lag(mrr) OVER (PARTITION BY customer_id ORDER BY month ASC)
    END AS mrr_change,
    row_number() OVER (PARTITION BY customer_id ORDER BY month ASC) AS mrr_rank_asc,
    row_number() OVER (PARTITION BY customer_id ORDER BY month DESC) AS mrr_rank_desc
FROM time_series_revenue
WHERE
    mrr IS NOT null
    AND (canceled_at IS null OR month <= canceled_at)
    AND month = date_trunc(current_date(), MONTH)
ORDER BY customer_id ASC, month ASC
