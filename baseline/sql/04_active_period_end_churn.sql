WITH RECURSIVE active_period_params AS (
    SELECT
        INTERVAL '14 day' AS allowed_gap,
        '2020-05-10'::date AS observe_end,
        '2020-02-09'::date AS observe_start
),

end_dates AS (
    SELECT DISTINCT
        s.account_id,
        s.start_date,
        s.end_date,
        (s.end_date + p.allowed_gap)::date AS extension_max

    FROM socialnet7.subscription s

    CROSS JOIN active_period_params p

    WHERE
        s.end_date BETWEEN p.observe_start AND p.observe_end
),

extensions AS (
    SELECT DISTINCT
        e.account_id,
        e.end_date

    FROM end_dates e

    INNER JOIN socialnet7.subscription s
        ON e.account_id = s.account_id

        AND s.start_date <= e.extension_max

        AND (
            s.end_date > e.end_date
            OR s.end_date IS NULL
        )
),

churns AS (

    /* Anchor:
       Find subscription end dates that were NOT extended
       by another subscription within the allowed gap.
    */
    SELECT
        e.account_id,
        e.start_date,
        e.end_date AS churn_date

    FROM end_dates e

    LEFT JOIN extensions x
        ON e.account_id = x.account_id
        AND e.end_date = x.end_date

    WHERE x.end_date IS NULL


    UNION


    /* Recursive step:
       Walk backward through earlier connected subscriptions
       to find the beginning of the active period that churned.
    */
    SELECT
        s.account_id,
        s.start_date,
        c.churn_date

    FROM socialnet7.subscription s

    CROSS JOIN active_period_params p

    INNER JOIN churns c
        ON s.account_id = c.account_id
        AND s.start_date < c.start_date
        AND s.end_date >= (c.start_date - p.allowed_gap)::date
)

INSERT INTO socialnet7.active_period
(
    account_id,
    start_date,
    churn_date
)

SELECT
    account_id,
    MIN(start_date) AS start_date,
    churn_date

FROM churns

GROUP BY
    account_id,
    churn_date

ORDER BY
    account_id,
    churn_date;

--Output
-- INSERT 0 1159

SELECT
    CASE
        WHEN churn_date IS NULL THEN 'Ongoing'
        ELSE 'Churned'
    END AS period_status,

    COUNT(*) AS n_periods,
    COUNT(DISTINCT account_id) AS n_accounts,
    MIN(start_date) AS earliest_start,
    MAX(start_date) AS latest_start,
    MIN(churn_date) AS earliest_churn,
    MAX(churn_date) AS latest_churn

FROM socialnet7.active_period

GROUP BY
    CASE
        WHEN churn_date IS NULL THEN 'Ongoing'
        ELSE 'Churned'
    END

ORDER BY period_status;

--  period_status | n_periods | n_accounts | earliest_start | latest_start | earliest_churn | latest_churn 
-- ---------------+-----------+------------+----------------+--------------+----------------+--------------
--  Churned       |      1159 |       1159 | 2020-01-01     | 2020-04-10   | 2020-02-09     | 2020-05-10
--  Ongoing       |     12416 |      12416 | 2020-01-01     | 2020-05-10   |                | 
-- (2 rows)
