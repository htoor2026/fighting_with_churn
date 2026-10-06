-- 03_activity_churn.sql
-- Purpose:
-- Measure behavioral churn by identifying accounts that were active
-- during the start activity window but inactive during the end activity window.
--
-- Definition:
-- An account is active if it generated at least one event during the
-- previous 1-month inactivity window.
--
-- Output:
-- churn_rate
-- retention_rate
-- n_start
-- n_churn

WITH
date_range AS (
    SELECT
        '2020-03-01'::TIMESTAMP AS start_date,
        '2020-04-01'::TIMESTAMP AS end_date,
        INTERVAL '1 month' AS inactivity_interval
),

start_accounts AS (
    SELECT DISTINCT e.account_id
    FROM socialnet7.event e
    INNER JOIN date_range d
        ON e.event_time > d.start_date - d.inactivity_interval
        AND e.event_time <= d.start_date
),

end_accounts AS (
    SELECT DISTINCT e.account_id
    FROM socialnet7.event e
    INNER JOIN date_range d
        ON e.event_time > d.end_date - d.inactivity_interval
        AND e.event_time <= d.end_date
),

churned_accounts AS (
    SELECT s.account_id
    FROM start_accounts s
    LEFT JOIN end_accounts e
        ON s.account_id = e.account_id
    WHERE e.account_id IS NULL
),

start_count AS (
    SELECT COUNT(*) AS n_start
    FROM start_accounts
),

churn_count AS (
    SELECT COUNT(*) AS n_churn
    FROM churned_accounts
)

SELECT
    n_churn::float / NULLIF(n_start, 0) AS churn_rate,
    1.0 - n_churn::float / NULLIF(n_start, 0) AS retention_rate,
    n_start,
    n_churn
FROM start_count
CROSS JOIN churn_count;

--      churn_rate      |   retention_rate   | n_start | n_churn 
-- ---------------------+--------------------+---------+---------
--  0.05914517451927458 | 0.9408548254807254 |   10973 |     649
-- (1 row)
