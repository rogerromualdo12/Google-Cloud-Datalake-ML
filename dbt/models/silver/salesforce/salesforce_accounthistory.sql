WITH source AS (
    SELECT * FROM {{ source('sni_salesforce', 'AccountHistory') }}
),

renamed AS (
    SELECT
        Id,
        IsDeleted,
        AccountId,
        CreatedById,
        CreatedDate,
        Field,
        DataType,
        OldValue,
        NewValue
    FROM source
)

SELECT * FROM renamed
