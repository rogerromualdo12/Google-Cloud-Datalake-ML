WITH source AS (
    SELECT * FROM {{ source('sni_stripe', 'prices') }}
),

renamed AS (
    SELECT
        id,
        object,
        active,
        billing_scheme,
        currency,
        custom_unit_amount,
        livemode,
        lookup_key,
        metadata_itemcode,
        metadata_taxcode,
        metadata_netsuite_service_sale_item_id,
        metadata_netsuite_service_sale_item_link,
        nickname,
        product,
        recurring_aggregate_usage,
        recurring_interval,
        recurring_interval_count,
        recurring_trial_period_days,
        recurring_usage_type,
        tax_behavior,
        tiers_mode,
        transform_quantity,
        type,
        unit_amount,
        unit_amount_decimal,
        metadata,
        recurring,
        metadata_nickname,
        timestamp_seconds(cast(created AS int)) AS created

    FROM source
)

SELECT * FROM renamed
