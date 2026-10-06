-- 01_net_mrr_retention.sql
-- Purpose:
-- Measure how much recurring revenue from the starting customer base
-- is still retained at the end of the measurement period.
--
-- Output:
-- net_mrr_retention_rate
-- net_mrr_churn_rate
-- start_mrr
-- retain_mrr

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

retained_accounts AS (
    SELECT
        s.account_id,
        e.total_mrr
    FROM start_accounts s
    INNER JOIN end_accounts e
        ON s.account_id = e.account_id
),

start_mrr AS (
    SELECT SUM(total_mrr) AS start_mrr
    FROM start_accounts
),

retain_mrr AS (
    SELECT SUM(total_mrr) AS retain_mrr
    FROM retained_accounts
)

SELECT
    retain_mrr / NULLIF(start_mrr, 0) AS net_mrr_retention_rate,
    1.0 - retain_mrr / NULLIF(start_mrr, 0) AS net_mrr_churn_rate,
    start_mrr,
    retain_mrr
FROM start_mrr
CROSS JOIN retain_mrr;



--  net_mrr_retention_rate | net_mrr_churn_rate  | start_mrr | retain_mrr 
-- ------------------------+---------------------+-----------+------------
--      0.9674499229583975 | 0.03255007704160251 |    103840 |     100460
-- (1 row)