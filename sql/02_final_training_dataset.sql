-- ============================================================
-- 02_final_training_dataset.sql
-- Build the final customer-observation modeling table
-- ============================================================
--
-- Final design:
--   * one row per account + observation_date
--   * churn label from socialnet7.observation
--   * demographics from socialnet7.account
--   * account tenure from first subscription start
--   * ALL 8 behavior features calculated directly from raw event data
--   * 28-day lookback window ending on the observation date
--   * synthetic subscription features joined from
--     socialnet7.subscription_features
--
-- This intentionally avoids rebuilding missing metric IDs 4-7 in the
-- legacy metric table. The final portfolio pipeline reads all behavior
-- types directly from socialnet7.event.
-- ============================================================

DROP TABLE IF EXISTS socialnet7.churn_training_ready;

CREATE TABLE socialnet7.churn_training_ready AS

WITH account_start AS (
    SELECT
        s.account_id,
        MIN(s.start_date)::date AS first_start_date
    FROM socialnet7.subscription s
    GROUP BY s.account_id
),

behavior_28d AS (
    SELECT
        o.account_id,
        o.observation_date,

        COUNT(*) FILTER (
            WHERE t.event_type_name = 'post'
        )::integer AS post_per_month,

        COUNT(*) FILTER (
            WHERE t.event_type_name = 'newfriend'
        )::integer AS newfriend_per_month,

        COUNT(*) FILTER (
            WHERE t.event_type_name = 'like'
        )::integer AS like_per_month,

        COUNT(*) FILTER (
            WHERE t.event_type_name = 'adview'
        )::integer AS adview_per_month,

        COUNT(*) FILTER (
            WHERE t.event_type_name = 'dislike'
        )::integer AS dislike_per_month,

        COUNT(*) FILTER (
            WHERE t.event_type_name = 'unfriend'
        )::integer AS unfriend_per_month,

        COUNT(*) FILTER (
            WHERE t.event_type_name = 'message'
        )::integer AS message_per_month,

        COUNT(*) FILTER (
            WHERE t.event_type_name = 'reply'
        )::integer AS reply_per_month

    FROM socialnet7.observation o

    LEFT JOIN socialnet7.event e
        ON e.account_id = o.account_id
        AND e.event_time > o.observation_date::timestamp - INTERVAL '28 day'
        AND e.event_time <= o.observation_date::timestamp

    LEFT JOIN socialnet7.event_type t
        ON t.event_type_id = e.event_type_id

    GROUP BY
        o.account_id,
        o.observation_date
)

SELECT
    o.account_id,
    o.observation_date,
    o.is_churn,

    a.channel,
    a.country,

    FLOOR(
        DATE_PART(
            'day',
            o.observation_date::timestamp
            - a.date_of_birth::timestamp
        ) / 365.25
    )::integer AS customer_age,

    GREATEST(
        0,
        o.observation_date - s.first_start_date
    )::integer AS account_tenure_days,

    b.post_per_month,
    b.newfriend_per_month,
    b.like_per_month,
    b.adview_per_month,
    b.dislike_per_month,
    b.unfriend_per_month,
    b.message_per_month,
    b.reply_per_month,

    sf.current_plan,
    sf.current_mrr,
    sf.bill_period_months,
    sf.discount,
    sf.mrr_change,
    sf.upgrade_flag,
    sf.downsell_flag,
    sf.upgrade_last_90d,
    sf.downsell_last_90d

FROM socialnet7.observation o

INNER JOIN socialnet7.account a
    ON a.id = o.account_id

INNER JOIN account_start s
    ON s.account_id = o.account_id

INNER JOIN behavior_28d b
    ON b.account_id = o.account_id
    AND b.observation_date = o.observation_date

INNER JOIN socialnet7.subscription_features sf
    ON sf.account_id = o.account_id
    AND sf.observation_date = o.observation_date

ORDER BY
    o.observation_date,
    o.account_id;


CREATE UNIQUE INDEX IF NOT EXISTS
    churn_training_ready_account_observation_idx
ON socialnet7.churn_training_ready
    (account_id, observation_date);


-- ------------------------------------------------------------
-- Validation expected from the completed project
-- ------------------------------------------------------------
-- Final project dataset:
--   32,897 account-observation rows
--   645 churn observations
--   churn rate approximately 1.96%
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT account_id) AS unique_accounts,
    COUNT(*) FILTER (WHERE is_churn = TRUE) AS churn_observations,
    COUNT(*) FILTER (WHERE is_churn = FALSE) AS retained_observations,
    ROUND(
        100.0
        * COUNT(*) FILTER (WHERE is_churn = TRUE)
        / NULLIF(COUNT(*), 0),
        2
    ) AS churn_rate_pct,
    MIN(observation_date) AS first_observation,
    MAX(observation_date) AS last_observation
FROM socialnet7.churn_training_ready;


-- ------------------------------------------------------------
-- Optional psql export
-- Run from the repository root and change the path if needed.
-- ------------------------------------------------------------
--
-- \copy (
--     SELECT *
--     FROM socialnet7.churn_training_ready
--     ORDER BY observation_date, account_id
-- ) TO 'data/churn_training_final.csv' WITH CSV HEADER;
