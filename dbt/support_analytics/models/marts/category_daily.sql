SELECT
    DATE_TRUNC('day', created_at) AS date,
    category,
    COUNT(*) AS tickets
FROM {{ ref('stg_support_tickets') }}
GROUP BY 1,2
ORDER BY 1,2
