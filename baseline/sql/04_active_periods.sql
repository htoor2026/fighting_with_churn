WITH RECURSIVE active_period_params AS (
    SELECT
        INTERVAL '7 day' AS allowed_gap,
        '2020-05-10'::date AS calc_date
),

active AS (

    /* Anchor:
       Find accounts with a subscription active on calc_date.
    */
    SELECT
        s.account_id,
        MIN(s.start_date) AS start_date

    FROM socialnet7.subscription s

    CROSS JOIN active_period_params p

    WHERE
        s.start_date <= p.calc_date
        AND (
            s.end_date > p.calc_date
            OR s.end_date IS NULL
        )

    GROUP BY
        s.account_id


    UNION


    /* Recursive step:
       Walk backward through earlier subscriptions
       that are separated by no more than allowed_gap.
    */
    SELECT
        s.account_id,
        s.start_date

    FROM socialnet7.subscription s

    CROSS JOIN active_period_params p

    INNER JOIN active a
        ON s.account_id = a.account_id
        AND s.start_date < a.start_date
        AND s.end_date >= (a.start_date - p.allowed_gap)::date
)

INSERT INTO socialnet7.active_period
(
    account_id,
    start_date,
    churn_date
)

SELECT
    a.account_id,
    MIN(a.start_date) AS start_date,
    NULL::date AS churn_date

FROM active a

GROUP BY
    a.account_id

ORDER BY
    a.account_id;

-- Output
-- INSERT 0 12416

churn=> SELECT
    COUNT(*) AS n_active_periods,
    COUNT(DISTINCT account_id) AS n_accounts,
    MIN(start_date) AS earliest_start,
    MAX(start_date) AS latest_start,
    COUNT(churn_date) AS n_with_churn_date,
    COUNT(*) - COUNT(churn_date) AS n_ongoing
FROM socialnet7.active_period;


--  n_active_periods | n_accounts | earliest_start | latest_start | n_with_churn_date | n_ongoing 
-- ------------------+------------+----------------+--------------+-------------------+-----------
--             12416 |      12416 | 2020-01-01     | 2020-05-10   |                 0 |     12416
-- (1 row)

SELECT
    account_id,
    start_date,
    churn_date
FROM socialnet7.active_period
ORDER BY account_id
LIMIT 20;
--  account_id | start_date | churn_date 
-- ------------+------------+------------
--           0 | 2020-01-12 | 
--           1 | 2020-01-15 | 
--           2 | 2020-01-05 | 
--           3 | 2020-01-12 | 
--           4 | 2020-01-31 | 
--           5 | 2020-01-22 | 
--           6 | 2020-01-29 | 
--           8 | 2020-01-22 | 
--           9 | 2020-01-03 | 
--          10 | 2020-01-20 | 
--          11 | 2020-01-10 | 
--          12 | 2020-01-21 | 
--          13 | 2020-01-05 | 
--          14 | 2020-01-17 | 
--          15 | 2020-01-09 | 
--          16 | 2020-01-02 | 
--          17 | 2020-01-19 | 
--          18 | 2020-01-20 | 
--          19 | 2020-01-09 | 
--          20 | 2020-01-27 | 
-- (20 rows)

