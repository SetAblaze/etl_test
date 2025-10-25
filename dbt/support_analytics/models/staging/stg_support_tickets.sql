WITH raw AS (
    SELECT
        CAST(ticket_id AS TEXT)        AS ticket_id,
        CAST(customer_id AS TEXT)      AS customer_id,
        CAST(agent_id AS TEXT)         AS agent_id,
        CAST(category AS TEXT)         AS category,
        CAST(created_at AS TIMESTAMP)  AS created_at,
        CAST(first_response_at AS TIMESTAMP) AS first_response_at,
        CAST(resolved_at AS TIMESTAMP) AS resolved_at,
        CAST(satisfaction_score AS NUMERIC)  AS satisfaction_score,
        CAST(is_repeat AS BOOLEAN)     AS is_repeat
    FROM {{ ref('support_tickets') }}
),
clean AS (
    SELECT
        ticket_id,
        customer_id,
        agent_id,
        COALESCE(NULLIF(TRIM(category), ''), 'unknown') AS category,
        created_at,
        first_response_at,
        resolved_at,
        satisfaction_score,
        COALESCE(is_repeat, FALSE) AS is_repeat
    FROM raw
    WHERE created_at IS NOT NULL
)
SELECT * FROM clean

