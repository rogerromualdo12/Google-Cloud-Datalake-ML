WITH source AS (
    SELECT id FROM {{ source('sni_fulcrum', 'organizations') }}
),

workflows AS (
    SELECT
        owner_id,
        count(*) AS workflows_count
    FROM {{ source('sni_fulcrum', 'workflows') }}
    GROUP BY 1
)

SELECT
    s.id,
    w.workflows_count
FROM source AS s
INNER JOIN workflows AS w ON s.id = w.owner_id
