\copy (
WITH observation_params AS (
    SELECT
        INTERVAL '7 day' AS metric_period,
        '2020-02-09'::timestamp AS obs_start,
        '2020-05-10'::timestamp AS obs_end
)

SELECT
    m.account_id,
    o.observation_date,
    o.is_churn,
    a.channel,
    a.country,

    DATE_PART(
        'day',
        o.observation_date::timestamp
        - a.date_of_birth::timestamp
    )::float / 365.0 AS customer_age,

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

    SUM(CASE WHEN n.metric_name = 'account_tenure'
        THEN m.metric_value ELSE 0 END) AS account_tenure,

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

    SUM(CASE WHEN n.metric_name = 'newfriend_pcnt_chng'
        THEN m.metric_value ELSE 0 END) AS newfriend_pcnt_chng,

    SUM(CASE WHEN n.metric_name = 'days_since_newfriend'
        THEN m.metric_value ELSE 0 END) AS days_since_newfriend

FROM socialnet7.metric m

INNER JOIN socialnet7.metric_name n
    ON n.metric_name_id = m.metric_name_id

CROSS JOIN observation_params p

INNER JOIN socialnet7.observation o
    ON m.account_id = o.account_id
    AND m.metric_time >
        (o.observation_date - p.metric_period)::timestamp
    AND m.metric_time <=
        o.observation_date::timestamp

INNER JOIN socialnet7.account a
    ON m.account_id = a.id

WHERE
    m.metric_time BETWEEN
        p.obs_start
        AND p.obs_end

GROUP BY
    m.account_id,
    o.observation_date,
    o.is_churn,
    a.channel,
    a.country,
    a.date_of_birth

ORDER BY
    o.observation_date,
    m.account_id
)
TO '/Users/toor/Desktop/fighting-churn-learning/output/churn_dataset_demographic.csv'
WITH CSV HEADER;
-- COPY 32897