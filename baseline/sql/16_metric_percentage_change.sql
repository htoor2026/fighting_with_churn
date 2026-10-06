-- This query is converting an 84-day unfriend count into an equivalent 28-day average rate.

-- The core is:

-- (28.0 / 84.0) * COUNT(*)

-- Since:

-- $$ \frac{28}{84}=\frac13 $$

-- you are basically doing:

-- $$ \text{28-day average unfriend count} = \frac{\text{unfriend events in last 84 days}}{3} $$

-- So:

-- 1 unfriend in 84 days  → 0.33 per 28 days
-- 2                    → 0.67
-- 3                    → 1.00
-- 5                    → 1.67

-- Why do this? Because unfriend is a rare event. A normal 28-day window may contain too many zeros, 
-- so using a longer 84-day window gives a more stable signal
-- , then you scale it back to a 28-day comparable rate.

-- That is a useful feature-engineering idea:

-- For sparse behaviors, use a longer observation window to reduce noise, then normalize to the desired time scale.

-- So this is effectively an 84-day smoothed unfriend rate expressed on a 28-day basis.

BEGIN;

INSERT INTO socialnet7.metric_name
    (metric_name_id, metric_name)
VALUES
    (1, 'newfriend_per_month')
ON CONFLICT DO NOTHING;


WITH date_vals AS (
    SELECT i::timestamp AS metric_date
    FROM generate_series(
        '2020-02-02'::timestamp,
        '2020-05-10'::timestamp,
        '7 day'::interval
    ) AS i
)

INSERT INTO socialnet7.metric
    (
        account_id,
        metric_time,
        metric_name_id,
        metric_value
    )

SELECT
    e.account_id,
    d.metric_date,
    1 AS metric_name_id,
    COUNT(*) AS metric_value

FROM socialnet7.event e

INNER JOIN date_vals d
    ON e.event_time < d.metric_date
    AND e.event_time >= d.metric_date - INTERVAL '28 day'

INNER JOIN socialnet7.event_type t
    ON t.event_type_id = e.event_type_id

WHERE
    t.event_type_name = 'newfriend'

GROUP BY
    e.account_id,
    d.metric_date

ON CONFLICT DO NOTHING;

COMMIT;


SELECT
    n.metric_name,
    COUNT(m.*) AS n_rows,
    MIN(m.metric_time) AS first_metric_time,
    MAX(m.metric_time) AS last_metric_time

FROM socialnet7.metric_name n

LEFT JOIN socialnet7.metric m
    ON m.metric_name_id = n.metric_name_id

WHERE
    n.metric_name = 'newfriend_per_month'

GROUP BY
    n.metric_name;

-- BEGIN
-- INSERT 0 1
-- INSERT 0 145906
-- COMMIT
--      metric_name     | n_rows |  first_metric_time  |  last_metric_time   
-- ---------------------+--------+---------------------+---------------------
--  newfriend_per_month | 145906 | 2020-02-02 00:00:00 | 2020-05-10 00:00:00
-- (1 row)

WITH end_metric AS (
    SELECT
        m.account_id,
        m.metric_time,
        m.metric_value AS end_value
    FROM socialnet7.metric m
    INNER JOIN socialnet7.metric_name n
        ON n.metric_name_id = m.metric_name_id
    WHERE
        n.metric_name = 'newfriend_per_month'
        AND m.metric_time BETWEEN
            '2020-04-01'::timestamp
            AND '2020-05-10'::timestamp
),

start_metric AS (
    SELECT
        m.account_id,
        m.metric_time,
        m.metric_value AS start_value
    FROM socialnet7.metric m
    INNER JOIN socialnet7.metric_name n
        ON n.metric_name_id = m.metric_name_id
    WHERE
        n.metric_name = 'newfriend_per_month'
        AND m.metric_time BETWEEN
            ('2020-04-01'::timestamp - INTERVAL '4 week')
            AND
            ('2020-05-10'::timestamp - INTERVAL '4 week')
)

SELECT
    s.account_id,
    s.metric_time + INTERVAL '4 week' AS metric_time,
    s.start_value,
    e.end_value,
    COALESCE(e.end_value, 0.0) / s.start_value - 1.0
        AS percent_change

FROM start_metric s

LEFT JOIN end_metric e
    ON s.account_id = e.account_id
    AND e.metric_time =
        s.metric_time + INTERVAL '4 week'

WHERE
    s.start_value > 0

ORDER BY
    s.account_id,
    metric_time;
--     account_id |     metric_time     | start_value | end_value |    percent_change     
-- ------------+---------------------+-------------+-----------+-----------------------
--           0 | 2020-04-05 00:00:00 |           3 |         2 |   -0.3333333134651184
--           0 | 2020-04-12 00:00:00 |           2 |         3 |                   0.5
--           0 | 2020-04-19 00:00:00 |           2 |         3 |                   0.5
--           0 | 2020-04-26 00:00:00 |           1 |         5 |                     4
--           0 | 2020-05-03 00:00:00 |           2 |         3 |                   0.5
--           0 | 2020-05-10 00:00:00 |           3 |         4 |    0.3333333730697632
--           1 | 2020-04-05 00:00:00 |           5 |         8 |    0.6000000238418579
--           1 | 2020-04-12 00:00:00 |           9 |         6 |   -0.3333333134651184
--           1 | 2020-04-19 00:00:00 |           9 |         8 |   -0.1111111044883728
--           1 | 2020-04-26 00:00:00 |          10 |         7 |  -0.30000001192092896
--           1 | 2020-05-03 00:00:00 |           8 |         7 |                -0.125
--           1 | 2020-05-10 00:00:00 |           6 |         5 |   -0.1666666865348816
--           2 | 2020-04-05 00:00:00 |           2 |         2 |                     0
--           2 | 2020-04-12 00:00:00 |           2 |         2 |                     0
--           2 | 2020-04-19 00:00:00 |           2 |         2 |                     0
--           2 | 2020-04-26 00:00:00 |           2 |         2 |                     0
--           2 | 2020-05-03 00:00:00 |           2 |         3 |                   0.5
--           2 | 2020-05-10 00:00:00 |           2 |         4 |                     1
--           3 | 2020-04-05 00:00:00 |          21 |        11 |    -0.476190447807312
--           3 | 2020-04-12 00:00:00 |          19 |         9 |   -0.5263157784938812
--           3 | 2020-04-19 00:00:00 |          20 |         9 |    -0.550000011920929
--           3 | 2020-04-26 00:00:00 |          15 |        12 |  -0.19999998807907104
--           3 | 2020-05-03 00:00:00 |          11 |        14 |   0.27272725105285645
--           3 | 2020-05-10 00:00:00 |           9 |        13 |    0.4444444179534912
--           4 | 2020-04-05 00:00:00 |          12 |        16 |    0.3333333730697632
--           4 | 2020-04-12 00:00:00 |          13 |        20 |    0.5384615659713745
--           4 | 2020-04-19 00:00:00 |          14 |        16 |   0.14285719394683838
--           4 | 2020-04-26 00:00:00 |          17 |        13 |  -0.23529410362243652
--           4 | 2020-05-03 00:00:00 |          16 |        17 |                0.0625
--           4 | 2020-05-10 00:00:00 |          20 |        16 |  -0.19999998807907104
--           5 | 2020-04-05 00:00:00 |           2 |         3 |                   0.5
--           5 | 2020-04-12 00:00:00 |           2 |         3 |                   0.5
--           5 | 2020-04-19 00:00:00 |           2 |         5 |                   1.5
--           5 | 2020-04-26 00:00:00 |           2 |         5 |                   1.5
--           5 | 2020-05-03 00:00:00 |           3 |         5 |    0.6666666269302368
--           5 | 2020-05-10 00:00:00 |           3 |         5 |    0.6666666269302368
--           6 | 2020-04-05 00:00:00 |           1 |         3 |                     2
--           6 | 2020-04-12 00:00:00 |           1 |         3 |                     2
--           6 | 2020-04-19 00:00:00 |           3 |         1 |   -0.6666666567325592
--           6 | 2020-04-26 00:00:00 |           4 |           |                    -1
--           6 | 2020-05-03 00:00:00 |           3 |           |                    -1
--           6 | 2020-05-10 00:00:00 |           3 |           |                    -1
--           8 | 2020-04-05 00:00:00 |           6 |         9 |                   0.5
--           8 | 2020-04-12 00:00:00 |           7 |        10 |    0.4285714626312256
-- :