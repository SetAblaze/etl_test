WITH base AS (
    SELECT * FROM {{ ref('stg_support_tickets') }}
),
calc AS (
    SELECT
        DATE_TRUNC('day', created_at) AS date,
        EXTRACT(EPOCH FROM (resolved_at - created_at))/3600.0 AS resolution_hours,
        EXTRACT(EPOCH FROM (first_response_at - created_at))/3600.0 AS first_response_hours,
        satisfaction_score,
        is_repeat
    FROM base
)
SELECT
    date,
    COUNT(*) AS tickets,
    AVG(resolution_hours) FILTER (WHERE resolution_hours IS NOT NULL) AS avg_resolution_hours,
    AVG(first_response_hours) FILTER (WHERE first_response_hours IS NOT NULL) AS avg_first_response_hours,
    AVG(satisfaction_score) FILTER (WHERE satisfaction_score IS NOT NULL) AS avg_satisfaction,
    (SUM(CASE WHEN is_repeat THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*),0)) AS repeat_rate
FROM calc
GROUP BY 1
ORDER BY 1
