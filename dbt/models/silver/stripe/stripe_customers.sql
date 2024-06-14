WITH source AS (
    SELECT * FROM {{ source('sni_stripe', 'customers') }}
),

renamed AS (
    SELECT
        id,
        object,
        address,
        balance,
        created,
        currency,
        default_currency,
        default_source,
        delinquent,
        description,
        discount,
        email,
        invoice_prefix,
        invoice_settings_custom_fields,
        invoice_settings_default_payment_method,
        invoice_settings_footer,
        invoice_settings_rendering_options,
        livemode,
        metadata_address_validation_status,
        metadata_account_region,
        metadata_netsuite_customer_id,
        metadata_netsuite_customer_link,
        metadata_organization_id,
        name,
        next_invoice_sequence,
        phone,
        preferred_locales,
        shipping,
        tax_exempt,
        test_clock,
        address_city,
        address_country,
        address_line1,
        address_line2,
        address_postal_code,
        address_state,
        shipping_address_city,
        shipping_address_country,
        shipping_address_line1,
        shipping_address_line2,
        shipping_address_postal_code,
        shipping_address_state,
        shipping_name,
        shipping_phone,
        preferred_locales_0,
        metadata,
        metadata_rollup_billing_parent

    FROM source
)

SELECT * FROM renamed
WHERE id NOT IN ("cus_BKVLldGgX7vDXk")
