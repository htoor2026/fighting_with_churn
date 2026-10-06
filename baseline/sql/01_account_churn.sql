-- 02_account_churn.sql
-- Purpose:
-- Measure the proportion of starting accounts that are no longer active
-- at the end of the measurement period.

WITH
date_range AS (
    SELECT
        '2020-03-01'::date AS start_date,
        '2020-04-01'::date AS end_date
),

start_accounts AS (
    SELECT DISTINCT account_id
    FROM socialnet7.subscription s
    INNER JOIN date_range d
        ON s.start_date <= d.start_date
        AND (
            s.end_date > d.start_date
            OR s.end_date IS NULL
        )
),

end_accounts AS (
    SELECT DISTINCT account_id
    FROM socialnet7.subscription s
    INNER JOIN date_range d
        ON s.start_date <= d.end_date
        AND (
            s.end_date > d.end_date
            OR s.end_date IS NULL
        )
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
--  0.03255007704160247 | 0.9674499229583975 |   10384 |     338
-- (1 row)