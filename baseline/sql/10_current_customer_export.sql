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
    d.last_metric_time AS observation_date,

    a.channel,
    a.country,

    DATE_PART(
        'day',
        d.last_metric_time::timestamp
        - a.date_of_birth::timestamp
    )::float / 365.0 AS customer_age,

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

INNER JOIN active_accounts aa
    ON aa.account_id = m.account_id

INNER JOIN socialnet7.account a
    ON a.id = m.account_id

WHERE
    m.metric_time = d.last_metric_time

GROUP BY
    m.account_id,
    d.last_metric_time,
    a.channel,
    a.country,
    a.date_of_birth,
    t.account_tenure

ORDER BY
    m.account_id
)
TO '/Users/toor/Desktop/fighting-churn-learning/output/churn_dataset_demographic_current.csv'
WITH CSV HEADER;

--COPY 11832