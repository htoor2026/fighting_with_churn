-- 05_normalized_churn.sql
-- Purpose:
-- Normalize churn measured over an arbitrary time period into
-- equivalent monthly and annual churn rates.
--
-- This is useful when comparing churn measurements that use
-- different measurement-window lengths.
--
-- Output:
-- n_start
-- n_churn
-- measured_churn
-- period_days
-- annual_churn
-- monthly_churn

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
    n_start,
    n_churn,

    n_churn::float / NULLIF(n_start, 0)
        AS measured_churn,

    d.end_date - d.start_date
        AS period_days,

    1.0 - POWER(
        1.0 - n_churn::float / NULLIF(n_start, 0),
        365.0 / NULLIF((d.end_date - d.start_date)::float, 0)
    ) AS annual_churn,

    1.0 - POWER(
        1.0 - n_churn::float / NULLIF(n_start, 0),
        (365.0 / 12.0)
        / NULLIF((d.end_date - d.start_date)::float, 0)
    ) AS monthly_churn

FROM start_count
CROSS JOIN churn_count
CROSS JOIN date_range d;


--  n_start | n_churn |   measured_churn    | period_days |    annual_churn    |    monthly_churn     
-- ---------+---------+---------------------+-------------+--------------------+----------------------
--    10384 |     338 | 0.03255007704160247 |          31 | 0.3226905873384659 | 0.031947466429487203
-- (1 row)
