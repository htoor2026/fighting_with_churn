WITH RECURSIVE observation_params AS (
    SELECT
        INTERVAL '1 month' AS obs_interval,
        INTERVAL '1 week' AS lead_time,
        '2020-02-09'::date AS obs_start,
        '2020-05-10'::date AS obs_end
),

observations AS (

    /* Anchor:
       Create the first possible observation for each active period.
    */
    SELECT
        ap.account_id,
        ap.start_date,
        1 AS obs_count,

        (
            ap.start_date
            + p.obs_interval
            - p.lead_time
        )::date AS obs_date,

        CASE
            WHEN ap.churn_date >= (
                    ap.start_date
                    + p.obs_interval
                    - p.lead_time
                 )::date
             AND ap.churn_date < (
                    ap.start_date
                    + 2 * p.obs_interval
                    - p.lead_time
                 )::date
            THEN TRUE
            ELSE FALSE
        END AS is_churn

    FROM socialnet7.active_period ap

    CROSS JOIN observation_params p

    WHERE
        ap.churn_date > (
            p.obs_start
            + p.obs_interval
            - p.lead_time
        )::date
        OR ap.churn_date IS NULL


    UNION


    /* Recursive step:
       Generate the next monthly observation for the same account.
    */
    SELECT
        o.account_id,
        o.start_date,
        o.obs_count + 1 AS obs_count,

        (
            o.start_date
            + (o.obs_count + 1) * p.obs_interval
            - p.lead_time
        )::date AS obs_date,

        CASE
            WHEN ap.churn_date >= (
                    o.start_date
                    + (o.obs_count + 1) * p.obs_interval
                    - p.lead_time
                 )::date

             AND ap.churn_date < (
                    o.start_date
                    + (o.obs_count + 2) * p.obs_interval
                    - p.lead_time
                 )::date

            THEN TRUE
            ELSE FALSE
        END AS is_churn

    FROM observations o

    CROSS JOIN observation_params p

    INNER JOIN socialnet7.active_period ap
        ON ap.account_id = o.account_id

        AND (
            o.start_date
            + (o.obs_count + 1) * p.obs_interval
            - p.lead_time
        )::date >= ap.start_date

        AND (
            (
                o.start_date
                + (o.obs_count + 1) * p.obs_interval
                - p.lead_time
            )::date < ap.churn_date

            OR ap.churn_date IS NULL
        )

    WHERE
        (
            o.start_date
            + (o.obs_count + 1) * p.obs_interval
            - p.lead_time
        )::date <= p.obs_end
)

INSERT INTO socialnet7.observation
(
    account_id,
    observation_date,
    is_churn
)

SELECT DISTINCT
    o.account_id,
    o.obs_date,
    o.is_churn

FROM observations o

CROSS JOIN observation_params p

WHERE
    o.obs_date BETWEEN p.obs_start AND p.obs_end

ORDER BY
    o.account_id,
    o.obs_date;

--Output

-- INSERT 0 32897

SELECT
    COUNT(*) AS total_observations,

    COUNT(DISTINCT account_id) AS unique_accounts,

    COUNT(*) FILTER (
        WHERE is_churn = TRUE
    ) AS churn_observations,

    COUNT(*) FILTER (
        WHERE is_churn = FALSE
    ) AS non_churn_observations,

    ROUND(
        100.0
        * COUNT(*) FILTER (WHERE is_churn = TRUE)
        / NULLIF(COUNT(*), 0),
        2
    ) AS churn_rate_pct,

    MIN(observation_date) AS earliest_observation,

    MAX(observation_date) AS latest_observation

FROM socialnet7.observation;
-- total_observations | unique_accounts | churn_observations | non_churn_observations | churn_rate_pct | earliest_observation | latest_observation 
-- --------------------+-----------------+--------------------+------------------------+----------------+----------------------+--------------------
--               32897 |           12102 |                645 |                  32252 |           1.96 | 2020-02-09           | 2020-05-10
-- (1 row)

SELECT
    observation_date,

    COUNT(*) AS n_observations,

    COUNT(*) FILTER (
        WHERE is_churn = TRUE
    ) AS n_churn,

    COUNT(*) FILTER (
        WHERE is_churn = FALSE
    ) AS n_non_churn,

    ROUND(
        100.0
        * COUNT(*) FILTER (WHERE is_churn = TRUE)
        / NULLIF(COUNT(*), 0),
        2
    ) AS churn_rate_pct

FROM socialnet7.observation

GROUP BY
    observation_date

ORDER BY
    observation_date;
--  observation_date | n_observations | n_churn | n_non_churn | churn_rate_pct 
-- ------------------+----------------+---------+-------------+----------------
--  2020-02-09       |            306 |       0 |         306 |           0.00
--  2020-02-10       |            289 |       0 |         289 |           0.00
--  2020-02-11       |            281 |       0 |         281 |           0.00
--  2020-02-12       |            316 |       0 |         316 |           0.00
--  2020-02-13       |            269 |       0 |         269 |           0.00
--  2020-02-14       |            293 |       0 |         293 |           0.00
--  2020-02-15       |            269 |       0 |         269 |           0.00
--  2020-02-16       |            293 |       0 |         293 |           0.00
--  2020-02-17       |            340 |       0 |         340 |           0.00
--  2020-02-18       |            298 |       0 |         298 |           0.00
--  2020-02-19       |            311 |       0 |         311 |           0.00
--  2020-02-20       |            310 |       0 |         310 |           0.00
--  2020-02-21       |            299 |       0 |         299 |           0.00
--  2020-02-22       |            941 |       0 |         941 |           0.00
--  2020-02-23       |            337 |       0 |         337 |           0.00
--  2020-02-24       |            339 |       0 |         339 |           0.00
--  2020-02-25       |            349 |      13 |         336 |           3.72
--  2020-02-26       |            318 |       9 |         309 |           2.83
--  2020-02-27       |            319 |      10 |         309 |           3.13
--  2020-02-28       |            336 |      16 |         320 |           4.76
--  2020-02-29       |            325 |      11 |         314 |           3.38
--  2020-03-01       |            339 |      13 |         326 |           3.83
--  2020-03-02       |            356 |      11 |         345 |           3.09
--  2020-03-03       |            339 |      15 |         324 |           4.42
--  2020-03-04       |            315 |       7 |         308 |           2.22
--  2020-03-05       |            346 |      13 |         333 |           3.76
--  2020-03-06       |            338 |      11 |         327 |           3.25
--  2020-03-07       |            341 |      13 |         328 |           3.81
--  2020-03-08       |            313 |       8 |         305 |           2.56
--  2020-03-09       |            348 |      11 |         337 |           3.16
--  2020-03-10       |            322 |      15 |         307 |           4.66
--  2020-03-11       |            321 |      11 |         310 |           3.43
--  2020-03-12       |            360 |       9 |         351 |           2.50
--  2020-03-13       |            297 |       6 |         291 |           2.02
--  2020-03-14       |            319 |      12 |         307 |           3.76
--  2020-03-15       |            306 |      13 |         293 |           4.25
--  2020-03-16       |            320 |       7 |         313 |           2.19
--  2020-03-17       |            365 |       7 |         358 |           1.92
--  2020-03-18       |            340 |       7 |         333 |           2.06
--  2020-03-19       |            346 |       9 |         337 |           2.60
--  2020-03-20       |            348 |      14 |         334 |           4.02
--  2020-03-21       |            340 |      14 |         326 |           4.12
--  2020-03-22       |            357 |      13 |         344 |           3.64
--  2020-03-23       |            333 |      12 |         321 |           3.60
--  2020-03-24       |            287 |       6 |         281 |           2.09
--  2020-03-25       |            389 |       9 |         380 |           2.31
--  2020-03-26       |            377 |       9 |         368 |           2.39
--  2020-03-27       |            375 |      14 |         361 |           3.73
--  2020-03-28       |            337 |       6 |         331 |           1.78
--  2020-03-29       |            338 |       5 |         333 |           1.48
--  2020-03-30       |            356 |       8 |         348 |           2.25
--  2020-03-31       |            347 |       8 |         339 |           2.31
--  2020-04-01       |            366 |       9 |         357 |           2.46
:
