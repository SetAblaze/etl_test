WITH base AS (
    SELECT * FROM {{ ref('stg_support_tickets') }}
),
per_agent AS (
    SELECT
        agent_id,
        COUNT(*) AS tickets,
        AVG(EXTRACT(EPOCH FROM (resolved_at - created_at))/3600.0) AS avg_resolution_hours,
        AVG(satisfaction_score) AS avg_satisfaction,
        (SUM(CASE WHEN is_repeat THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*),0)) AS repeat_rate
    FROM base
    WHERE agent_id IS NOT NULL
    GROUP BY agent_id
),
norm AS (
    SELECT
        agent_id,
        tickets,
        avg_resolution_hours,
        avg_satisfaction,
        repeat_rate,
        (avg_resolution_hours - MIN(avg_resolution_hours) OVER ()) / NULLIF(MAX(avg_resolution_hours) OVER () - MIN(avg_resolution_hours) OVER (), 0) AS n_res_time,
        (avg_satisfaction - MIN(avg_satisfaction) OVER ()) / NULLIF(MAX(avg_satisfaction) OVER () - MIN(avg_satisfaction) OVER (), 0) AS n_satisfaction,
        (repeat_rate - MIN(repeat_rate) OVER ()) / NULLIF(MAX(repeat_rate) OVER () - MIN(repeat_rate) OVER (), 0) AS n_repeat
    FROM per_agent
)
SELECT
    agent_id,
    tickets,
    avg_resolution_hours,
    avg_satisfaction,
    repeat_rate,
    (COALESCE(1 - n_res_time, 0))*0.45 + (COALESCE(n_satisfaction,0))*0.45 + (COALESCE(1 - n_repeat,0))*0.10 AS score
FROM norm
ORDER BY score DESC NULLS LAST, tickets DESC
