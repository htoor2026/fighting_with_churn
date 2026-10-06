BEGIN;

-- Register the two missing metric names
INSERT INTO socialnet7.metric_name
    (metric_name_id, metric_name)
VALUES
    (2, 'post_per_month'),
    (3, 'adview_per_month')
ON CONFLICT DO NOTHING;


-- Calculate post_per_month
WITH date_vals AS (
    SELECT i::timestamp AS metric_date
    FROM generate_series(
        '2020-02-02'::timestamp,
        '2020-05-10'::timestamp,
        '7 day'::interval
    ) AS i
)
INSERT INTO socialnet7.metric
    (account_id, metric_time, metric_name_id, metric_value)
SELECT
    e.account_id,
    d.metric_date,
    2 AS metric_name_id,
    COUNT(*) AS metric_value
FROM socialnet7.event e
INNER JOIN date_vals d
    ON e.event_time < d.metric_date
    AND e.event_time >= d.metric_date - INTERVAL '28 day'
INNER JOIN socialnet7.event_type t
    ON t.event_type_id = e.event_type_id
WHERE
    t.event_type_name = 'post'
GROUP BY
    e.account_id,
    d.metric_date
ON CONFLICT DO NOTHING;


-- Calculate adview_per_month
WITH date_vals AS (
    SELECT i::timestamp AS metric_date
    FROM generate_series(
        '2020-02-02'::timestamp,
        '2020-05-10'::timestamp,
        '7 day'::interval
    ) AS i
)
INSERT INTO socialnet7.metric
    (account_id, metric_time, metric_name_id, metric_value)
SELECT
    e.account_id,
    d.metric_date,
    3 AS metric_name_id,
    COUNT(*) AS metric_value
FROM socialnet7.event e
INNER JOIN date_vals d
    ON e.event_time < d.metric_date
    AND e.event_time >= d.metric_date - INTERVAL '28 day'
INNER JOIN socialnet7.event_type t
    ON t.event_type_id = e.event_type_id
WHERE
    t.event_type_name = 'adview'
GROUP BY
    e.account_id,
    d.metric_date
ON CONFLICT DO NOTHING;

COMMIT;


-- Verify
SELECT
    n.metric_name_id,
    n.metric_name,
    COUNT(m.*) AS n_metric_rows,
    MIN(m.metric_time) AS first_metric_time,
    MAX(m.metric_time) AS last_metric_time
FROM socialnet7.metric_name n
LEFT JOIN socialnet7.metric m
    ON m.metric_name_id = n.metric_name_id
WHERE n.metric_name IN (
    'like_per_month',
    'post_per_month',
    'adview_per_month'
)
GROUP BY
    n.metric_name_id,
    n.metric_name
ORDER BY
    n.metric_name_id;

-- Output
-- BEGIN
-- INSERT 0 2
-- INSERT 0 163622
-- INSERT 0 163944
-- COMMIT
--  metric_name_id |   metric_name    | n_metric_rows |  first_metric_time  |  last_metric_time   
-- ----------------+------------------+---------------+---------------------+---------------------
--               0 | like_per_month   |        291768 | 2020-01-29 00:00:00 | 2020-05-10 00:00:00
--               2 | post_per_month   |        163622 | 2020-02-02 00:00:00 | 2020-05-10 00:00:00
--               3 | adview_per_month |        163944 | 2020-02-02 00:00:00 | 2020-05-10 00:00:00
-- (3 rows)

WITH num_metric AS (
    SELECT
        m.account_id,
        m.metric_time,
        m.metric_value AS num_value
    FROM socialnet7.metric m
    INNER JOIN socialnet7.metric_name n
        ON n.metric_name_id = m.metric_name_id
    WHERE
        n.metric_name = 'adview_per_month'
        AND m.metric_time BETWEEN '2020-04-01'::timestamp
                              AND '2020-05-10'::timestamp
),

den_metric AS (
    SELECT
        m.account_id,
        m.metric_time,
        m.metric_value AS den_value
    FROM socialnet7.metric m
    INNER JOIN socialnet7.metric_name n
        ON n.metric_name_id = m.metric_name_id
    WHERE
        n.metric_name = 'post_per_month'
        AND m.metric_time BETWEEN '2020-04-01'::timestamp
                              AND '2020-05-10'::timestamp
)

SELECT
    d.account_id,
    d.metric_time,
    n.num_value,
    d.den_value,
    CASE
        WHEN d.den_value > 0
        THEN COALESCE(n.num_value, 0.0) / d.den_value
        ELSE 0
    END AS metric_value
FROM den_metric d
LEFT JOIN num_metric n
    ON n.account_id = d.account_id
    AND n.metric_time = d.metric_time
ORDER BY
    d.account_id,
    d.metric_time;

--     account_id |     metric_time     | num_value | den_value | metric_value 
-- ------------+---------------------+-----------+-----------+--------------
--           0 | 2020-04-05 00:00:00 |       103 |         6 |    17.166666
--           0 | 2020-04-19 00:00:00 |       102 |         1 |          102
--           0 | 2020-04-26 00:00:00 |        99 |         3 |           33
--           0 | 2020-05-03 00:00:00 |       101 |         6 |    16.833334
--           0 | 2020-05-10 00:00:00 |       112 |         8 |           14
--           1 | 2020-04-05 00:00:00 |        20 |        33 |    0.6060606
--           1 | 2020-04-12 00:00:00 |        25 |        38 |   0.65789473
--           1 | 2020-04-19 00:00:00 |        24 |        35 |    0.6857143
--           1 | 2020-04-26 00:00:00 |        29 |        34 |   0.85294116
--           1 | 2020-05-03 00:00:00 |        31 |        36 |    0.8611111
--           1 | 2020-05-10 00:00:00 |        30 |        38 |    0.7894737
--           2 | 2020-04-05 00:00:00 |        13 |        20 |         0.65
--           2 | 2020-04-12 00:00:00 |         9 |        22 |    0.4090909
--           2 | 2020-04-19 00:00:00 |         4 |        21 |    0.1904762
--           2 | 2020-04-26 00:00:00 |         5 |        17 |   0.29411766
--           2 | 2020-05-03 00:00:00 |         8 |        19 |   0.42105263
--           2 | 2020-05-10 00:00:00 |        10 |        18 |    0.5555556
--           3 | 2020-04-05 00:00:00 |        17 |        61 |   0.27868852
--           3 | 2020-04-12 00:00:00 |        25 |        53 |    0.4716981
--           3 | 2020-04-19 00:00:00 |        24 |        48 |          0.5
--           3 | 2020-04-26 00:00:00 |        25 |        43 |    0.5813953
--           3 | 2020-05-03 00:00:00 |        22 |        34 |   0.64705884
--           3 | 2020-05-10 00:00:00 |        20 |        41 |    0.4878049
--           4 | 2020-04-05 00:00:00 |        57 |       100 |         0.57
--           4 | 2020-04-12 00:00:00 |        57 |        97 |   0.58762884
--           4 | 2020-04-19 00:00:00 |        57 |        93 |   0.61290324
--           4 | 2020-04-26 00:00:00 |        63 |        99 |    0.6363636
--           4 | 2020-05-03 00:00:00 |        61 |        86 |    0.7093023
--           4 | 2020-05-10 00:00:00 |        60 |        85 |    0.7058824
--           5 | 2020-04-05 00:00:00 |        13 |         4 |         3.25
--           5 | 2020-04-12 00:00:00 |        17 |         5 |          3.4
--           5 | 2020-04-19 00:00:00 |        15 |         6 |          2.5
--           5 | 2020-04-26 00:00:00 |        18 |         7 |    2.5714285
--           5 | 2020-05-03 00:00:00 |        17 |         6 |    2.8333333
--           5 | 2020-05-10 00:00:00 |        11 |         4 |         2.75
--           6 | 2020-04-05 00:00:00 |         5 |         5 |            1
--           6 | 2020-04-12 00:00:00 |         5 |         5 |            1
--           6 | 2020-04-19 00:00:00 |         6 |         6 |            1
--           6 | 2020-04-26 00:00:00 |         6 |         4 |          1.5
--           6 | 2020-05-03 00:00:00 |         7 |         3 |    2.3333333
--           6 | 2020-05-10 00:00:00 |         6 |         4 |          1.5
--           8 | 2020-04-05 00:00:00 |         9 |        16 |       0.5625
--           8 | 2020-04-12 00:00:00 |        11 |        16 |       0.6875
--           8 | 2020-04-19 00:00:00 |        12 |        14 |   0.85714287
-- :