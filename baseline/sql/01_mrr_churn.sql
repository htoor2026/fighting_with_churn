-- 04_mrr_churn.sql
-- Purpose:
-- Measure recurring revenue lost from:
--   1. customers who fully churned
--   2. retained customers whose MRR decreased (downsells)
--
-- Formula:
-- MRR churn rate =
--     (churned MRR + downsell MRR) / starting MRR
--
-- Output:
-- mrr_churn_rate
-- start_mrr
-- churn_mrr
-- downsell_mrr

WITH
date_range AS (
    SELECT
        '2020-03-01'::date AS start_date,
        '2020-04-01'::date AS end_date
),

start_accounts AS (
    SELECT
        account_id,
        SUM(mrr) AS total_mrr
    FROM socialnet7.subscription s
    INNER JOIN date_range d
        ON s.start_date <= d.start_date
        AND (
            s.end_date > d.start_date
            OR s.end_date IS NULL
        )
    GROUP BY account_id
),

end_accounts AS (
    SELECT
        account_id,
        SUM(mrr) AS total_mrr
    FROM socialnet7.subscription s
    INNER JOIN date_range d
        ON s.start_date <= d.end_date
        AND (
            s.end_date > d.end_date
            OR s.end_date IS NULL
        )
    GROUP BY account_id
),

churned_accounts AS (
    SELECT
        s.account_id,
        s.total_mrr
    FROM start_accounts s
    LEFT JOIN end_accounts e
        ON s.account_id = e.account_id
    WHERE e.account_id IS NULL
),

downsell_accounts AS (
    SELECT
        s.account_id,
        s.total_mrr - e.total_mrr AS downsell_amount
    FROM start_accounts s
    INNER JOIN end_accounts e
        ON s.account_id = e.account_id
    WHERE e.total_mrr < s.total_mrr
),

start_mrr AS (
    SELECT
        SUM(total_mrr) AS start_mrr
    FROM start_accounts
),

churn_mrr AS (
    SELECT
        COALESCE(SUM(total_mrr), 0.0) AS churn_mrr
    FROM churned_accounts
),

downsell_mrr AS (
    SELECT
        COALESCE(SUM(downsell_amount), 0.0) AS downsell_mrr
    FROM downsell_accounts
)

SELECT
    (churn_mrr + downsell_mrr)
        / NULLIF(start_mrr, 0) AS mrr_churn_rate,
    start_mrr,
    churn_mrr,
    downsell_mrr
FROM start_mrr
CROSS JOIN churn_mrr
CROSS JOIN downsell_mrr;

--    mrr_churn_rate    | start_mrr | churn_mrr | downsell_mrr 
-- ---------------------+-----------+-----------+--------------
--  0.03255007704160247 |    103840 |      3380 |            0
-- (1 row)