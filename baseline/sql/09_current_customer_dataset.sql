BEGIN;

INSERT INTO socialnet7.metric_name
    (metric_name_id, metric_name)
VALUES
    (8, 'account_tenure')
ON CONFLICT DO NOTHING;


WITH date_vals AS (
    SELECT
        i::timestamp AS metric_date
    FROM generate_series(
        '2020-02-02'::timestamp,
        '2020-05-10'::timestamp,
        '7 day'::interval
    ) AS i
),

account_start AS (
    SELECT
        s.account_id,
        MIN(s.start_date)::date AS first_start_date
    FROM socialnet7.subscription s
    GROUP BY
        s.account_id
)

INSERT INTO socialnet7.metric
    (
        account_id,
        metric_time,
        metric_name_id,
        metric_value
    )

SELECT
    a.account_id,
    d.metric_date,
    8 AS metric_name_id,

    GREATEST(
        0,
        d.metric_date::date - a.first_start_date
    )::double precision AS metric_value

FROM account_start a

CROSS JOIN date_vals d

WHERE
    a.first_start_date <= d.metric_date::date

ON CONFLICT DO NOTHING;

COMMIT;


SELECT
    n.metric_name_id,
    n.metric_name,
    COUNT(m.*) AS n_rows,
    MIN(m.metric_time) AS first_metric_time,
    MAX(m.metric_time) AS last_metric_time,
    MIN(m.metric_value) AS min_tenure,
    MAX(m.metric_value) AS max_tenure

FROM socialnet7.metric_name n

LEFT JOIN socialnet7.metric m
    ON m.metric_name_id = n.metric_name_id

WHERE
    n.metric_name = 'account_tenure'

GROUP BY
    n.metric_name_id,
    n.metric_name;

-- BEGIN
-- INSERT 0 1
-- INSERT 0 12279
-- COMMIT
--  metric_name_id |  metric_name   | n_rows |  first_metric_time  |  last_metric_time   | min_tenure | max_tenure 
-- ----------------+----------------+--------+---------------------+---------------------+------------+------------
--               8 | account_tenure | 177455 | 2020-02-02 00:00:00 | 2020-05-10 00:00:00 |          0 |        130
-- (1 row)

churn=>  SELECT
    COUNT(*) AS n_accounts_tenure_14_plus
FROM socialnet7.metric m

INNER JOIN socialnet7.metric_name n
    ON n.metric_name_id = m.metric_name_id

WHERE
    n.metric_name = 'account_tenure'
    AND m.metric_time = '2020-05-10'::timestamp
    AND m.metric_value >= 14;


--  n_accounts_tenure_14_plus 
-- ---------------------------
--                      13158
-- (1 row)

\copy (
WITH metric_date AS (
    SELECT
        MAX(m.metric_time) AS last_metric_time
    FROM socialnet7.metric m
),

account_tenures AS (
    SELECT
        m.account_id,
        m.metric_value AS account_tenure
    FROM socialnet7.metric m
    INNER JOIN socialnet7.metric_name n
        ON n.metric_name_id = m.metric_name_id
    CROSS JOIN metric_date d
    WHERE
        m.metric_time = d.last_metric_time
        AND n.metric_name = 'account_tenure'
        AND m.metric_value >= 14
),

active_accounts AS (
    SELECT DISTINCT
        s.account_id
    FROM socialnet7.subscription s
    CROSS JOIN metric_date d
    WHERE
        s.start_date <= d.last_metric_time
        AND (
            s.end_date > d.last_metric_time
            OR s.end_date IS NULL
        )
)

SELECT
    m.account_id,
    m.metric_time,

    SUM(CASE WHEN n.metric_name = 'like_per_month'
        THEN m.metric_value ELSE 0 END) AS like_per_month,

    SUM(CASE WHEN n.metric_name = 'newfriend_per_month'
        THEN m.metric_value ELSE 0 END) AS newfriend_per_month,

    SUM(CASE WHEN n.metric_name = 'post_per_month'
        THEN m.metric_value ELSE 0 END) AS post_per_month,

    SUM(CASE WHEN n.metric_name = 'adview_per_month'
        THEN m.metric_value ELSE 0 END) AS adview_per_month,

    SUM(CASE WHEN n.metric_name = 'dislike_per_month'
        THEN m.metric_value ELSE 0 END) AS dislike_per_month,

    SUM(CASE WHEN n.metric_name = 'unfriend_per_month'
        THEN m.metric_value ELSE 0 END) AS unfriend_per_month,

    SUM(CASE WHEN n.metric_name = 'message_per_month'
        THEN m.metric_value ELSE 0 END) AS message_per_month,

    SUM(CASE WHEN n.metric_name = 'reply_per_month'
        THEN m.metric_value ELSE 0 END) AS reply_per_month,

    SUM(CASE WHEN n.metric_name = 'adview_per_post'
        THEN m.metric_value ELSE 0 END) AS adview_per_post,

    SUM(CASE WHEN n.metric_name = 'reply_per_message'
        THEN m.metric_value ELSE 0 END) AS reply_per_message,

    SUM(CASE WHEN n.metric_name = 'like_per_post'
        THEN m.metric_value ELSE 0 END) AS like_per_post,

    SUM(CASE WHEN n.metric_name = 'post_per_message'
        THEN m.metric_value ELSE 0 END) AS post_per_message,

    SUM(CASE WHEN n.metric_name = 'unfriend_per_newfriend'
        THEN m.metric_value ELSE 0 END) AS unfriend_per_newfriend,

    SUM(CASE WHEN n.metric_name = 'dislike_pcnt'
        THEN m.metric_value ELSE 0 END) AS dislike_pcnt,

    SUM(CASE WHEN n.metric_name = 'unfriend_per_newfriend_scaled'
        THEN m.metric_value ELSE 0 END) AS unfriend_per_newfriend_scaled,

    SUM(CASE WHEN n.metric_name = 'newfriend_pcnt_chng'
        THEN m.metric_value ELSE 0 END) AS newfriend_pcnt_chng,

    SUM(CASE WHEN n.metric_name = 'days_since_newfriend'
        THEN m.metric_value ELSE 0 END) AS days_since_newfriend,

    SUM(CASE WHEN n.metric_name = 'unfriend_28day_avg_84day_obs'
        THEN m.metric_value ELSE 0 END) AS unfriend_28day_avg_84day_obs

FROM socialnet7.metric m

INNER JOIN socialnet7.metric_name n
    ON n.metric_name_id = m.metric_name_id

CROSS JOIN metric_date d

INNER JOIN account_tenures t
    ON t.account_id = m.account_id

INNER JOIN active_accounts a
    ON a.account_id = m.account_id

WHERE
    m.metric_time = d.last_metric_time

GROUP BY
    m.account_id,
    m.metric_time

ORDER BY
    m.account_id
)
TO '/Users/toor/Desktop/fighting-churn-learning/output/churn_dataset_current.csv'
WITH CSV HEADER;
-- COPY 11832

\copy (
WITH metric_date AS (
    SELECT
        MAX(m.metric_time) AS last_metric_time
    FROM socialnet7.metric m
),

account_tenures AS (
    SELECT
        m.account_id,
        m.metric_value AS account_tenure
    FROM socialnet7.metric m
    INNER JOIN socialnet7.metric_name n
        ON n.metric_name_id = m.metric_name_id
    CROSS JOIN metric_date d
    WHERE
        m.metric_time = d.last_metric_time
        AND n.metric_name = 'account_tenure'
        AND m.metric_value >= 14
),

active_accounts AS (
    SELECT DISTINCT
        s.account_id
    FROM socialnet7.subscription s
    CROSS JOIN metric_date d
    WHERE
        s.start_date <= d.last_metric_time
        AND (
            s.end_date > d.last_metric_time
            OR s.end_date IS NULL
        )
)

SELECT
    m.account_id,
    m.metric_time,

    SUM(
        CASE
            WHEN n.metric_name = 'like_per_month'
            THEN m.metric_value
            ELSE 0
        END
    ) AS like_per_month,

    SUM(
        CASE
            WHEN n.metric_name = 'newfriend_per_month'
            THEN m.metric_value
            ELSE 0
        END
    ) AS newfriend_per_month,

    SUM(
        CASE
            WHEN n.metric_name = 'post_per_month'
            THEN m.metric_value
            ELSE 0
        END
    ) AS post_per_month,

    SUM(
        CASE
            WHEN n.metric_name = 'adview_per_month'
            THEN m.metric_value
            ELSE 0
        END
    ) AS adview_per_month,

    SUM(
        CASE
            WHEN n.metric_name = 'dislike_per_month'
            THEN m.metric_value
            ELSE 0
        END
    ) AS dislike_per_month,

    SUM(
        CASE
            WHEN n.metric_name = 'unfriend_per_month'
            THEN m.metric_value
            ELSE 0
        END
    ) AS unfriend_per_month,

    SUM(
        CASE
            WHEN n.metric_name = 'message_per_month'
            THEN m.metric_value
            ELSE 0
        END
    ) AS message_per_month,

    SUM(
        CASE
            WHEN n.metric_name = 'reply_per_month'
            THEN m.metric_value
            ELSE 0
        END
    ) AS reply_per_month,

    t.account_tenure,

    SUM(
        CASE
            WHEN n.metric_name = 'adview_per_post'
            THEN m.metric_value
            ELSE 0
        END
    ) AS adview_per_post,

    SUM(
        CASE
            WHEN n.metric_name = 'reply_per_message'
            THEN m.metric_value
            ELSE 0
        END
    ) AS reply_per_message,

    SUM(
        CASE
            WHEN n.metric_name = 'like_per_post'
            THEN m.metric_value
            ELSE 0
        END
    ) AS like_per_post,

    SUM(
        CASE
            WHEN n.metric_name = 'post_per_message'
            THEN m.metric_value
            ELSE 0
        END
    ) AS post_per_message,

    SUM(
        CASE
            WHEN n.metric_name = 'unfriend_per_newfriend'
            THEN m.metric_value
            ELSE 0
        END
    ) AS unfriend_per_newfriend,

    SUM(
        CASE
            WHEN n.metric_name = 'dislike_pcnt'
            THEN m.metric_value
            ELSE 0
        END
    ) AS dislike_pcnt,

    SUM(
        CASE
            WHEN n.metric_name = 'unfriend_per_newfriend_scaled'
            THEN m.metric_value
            ELSE 0
        END
    ) AS unfriend_per_newfriend_scaled,

    SUM(
        CASE
            WHEN n.metric_name = 'newfriend_pcnt_chng'
            THEN m.metric_value
            ELSE 0
        END
    ) AS newfriend_pcnt_chng,

    SUM(
        CASE
            WHEN n.metric_name = 'days_since_newfriend'
            THEN m.metric_value
            ELSE 0
        END
    ) AS days_since_newfriend,

    SUM(
        CASE
            WHEN n.metric_name = 'unfriend_28day_avg_84day_obs'
            THEN m.metric_value
            ELSE 0
        END
    ) AS unfriend_28day_avg_84day_obs

FROM socialnet7.metric m

INNER JOIN socialnet7.metric_name n
    ON n.metric_name_id = m.metric_name_id

CROSS JOIN metric_date d

INNER JOIN account_tenures t
    ON t.account_id = m.account_id

INNER JOIN active_accounts a
    ON a.account_id = m.account_id

WHERE
    m.metric_time = d.last_metric_time

GROUP BY
    m.account_id,
    m.metric_time,
    t.account_tenure

ORDER BY
    m.account_id
)
TO '/Users/toor/Desktop/fighting-churn-learning/output/churn_dataset_current.csv'
WITH CSV HEADER;
-- copy 11832