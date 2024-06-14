WITH source AS (
    SELECT * FROM {{ source('sni_stripe', 'products') }}
),

renamed AS (
    SELECT
        id,
        object,
        active,
        attributes,
        created,
        default_price,
        description,
        images,
        livemode,
        metadata,
        name,
        package_dimensions,
        shippable,
        statement_descriptor,
        tax_code,
        type,
        unit_label,
        updated,
        url,
        metadata_plan_slug,
        metadata_product_type

    FROM source
)

SELECT * FROM renamed
