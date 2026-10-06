-- ============================================================
-- 01_subscription_extension.sql
-- Reconstructed portfolio version of the synthetic subscription layer
-- ============================================================
--
-- IMPORTANT
-- This file documents the final subscription-feature design used by the
-- portfolio project. It is reconstructed from the final dataset schema,
-- notebooks, application logic, and project workflow; it is not claimed
-- to be a byte-for-byte copy of the original one-off development script.
--
-- Design retained from the final project:
--   * plans: Basic / Plus / Premium
--   * base monthly prices: $10 / $20 / $35
--   * billing commitments: 1 / 3 / 6 months
--   * billing discounts: 0% / 5% / 10%
--   * behavior-informed synthetic upgrades / downsells
--   * MRR change and movement flags
--   * upgrade/downsell history over the previous 90 days
--
-- The behavioral simulation itself is ChurnSim/SocialNet. This file adds
-- a synthetic commercial layer for portfolio modeling. Upgrade/downsell
-- fields are predictive features, not causal treatment variables.
-- ============================================================

DROP TABLE IF EXISTS socialnet7.subscription_features;

CREATE TABLE socialnet7.subscription_features AS

WITH event_28d AS (
    SELECT
        o.account_id,
        o.observation_date,

        COUNT(*) FILTER (
            WHERE t.event_type_name = 'post'
        ) AS post_per_month,

        COUNT(*) FILTER (
            WHERE t.event_type_name = 'newfriend'
        ) AS newfriend_per_month,

        COUNT(*) FILTER (
            WHERE t.event_type_name = 'like'
        ) AS like_per_month,

        COUNT(*) FILTER (
            WHERE t.event_type_name = 'adview'
        ) AS adview_per_month,

        COUNT(*) FILTER (
            WHERE t.event_type_name = 'dislike'
        ) AS dislike_per_month,

        COUNT(*) FILTER (
            WHERE t.event_type_name = 'unfriend'
        ) AS unfriend_per_month,

        COUNT(*) FILTER (
            WHERE t.event_type_name = 'message'
        ) AS message_per_month,

        COUNT(*) FILTER (
            WHERE t.event_type_name = 'reply'
        ) AS reply_per_month

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
),

behavior_signal AS (
    SELECT
        e.*,

        (
            post_per_month
            + newfriend_per_month
            + like_per_month
            + message_per_month
            + reply_per_month
        )::double precision AS positive_engagement,

        (
            dislike_per_month
            + unfriend_per_month
        )::double precision AS negative_engagement,

        (
            post_per_month
            + newfriend_per_month
            + like_per_month
            + adview_per_month
            + dislike_per_month
            + unfriend_per_month
            + message_per_month
            + reply_per_month
        )::double precision AS total_activity

    FROM event_28d e
),

behavior_rank AS (
    SELECT
        b.*,

        PERCENT_RANK() OVER (
            PARTITION BY observation_date
            ORDER BY positive_engagement
        ) AS engagement_percentile,

        CASE
            WHEN total_activity > 0
            THEN negative_engagement / total_activity
            ELSE 0.0
        END AS negative_activity_share

    FROM behavior_signal b
),

base_assignment AS (
    SELECT
        b.*,

        -- Reproducible synthetic starting-plan mix.
        CASE
            WHEN MOD(ABS(account_id * 37), 10) < 6 THEN 'basic'
            WHEN MOD(ABS(account_id * 37), 10) < 9 THEN 'plus'
            ELSE 'premium'
        END AS previous_plan,

        -- Approximate 60% / 30% / 10% commitment mix.
        CASE
            WHEN MOD(ABS(account_id * 53), 10) < 6 THEN 1
            WHEN MOD(ABS(account_id * 53), 10) < 9 THEN 3
            ELSE 6
        END AS bill_period_months

    FROM behavior_rank b
),

movement_signal AS (
    SELECT
        b.*,

        -- Behavior-informed synthetic movement.
        -- Sparse deterministic gates keep movements occasional.
        CASE
            WHEN engagement_percentile >= 0.90
             AND negative_activity_share < 0.05
             AND previous_plan <> 'premium'
             AND MOD(
                    ABS(
                        account_id
                        + (observation_date - DATE '2020-01-01')
                    ),
                    7
                 ) = 0
            THEN 1
            ELSE 0
        END AS upgrade_flag,

        CASE
            WHEN (
                    engagement_percentile <= 0.10
                    OR negative_activity_share >= 0.10
                 )
             AND previous_plan <> 'basic'
             AND MOD(
                    ABS(
                        account_id
                        + (observation_date - DATE '2020-01-01')
                    ),
                    7
                 ) = 1
            THEN 1
            ELSE 0
        END AS downsell_flag

    FROM base_assignment b
),

plan_movement AS (
    SELECT
        m.*,

        CASE
            WHEN upgrade_flag = 1 AND previous_plan = 'basic'
                THEN 'plus'
            WHEN upgrade_flag = 1 AND previous_plan = 'plus'
                THEN 'premium'
            WHEN downsell_flag = 1 AND previous_plan = 'premium'
                THEN 'plus'
            WHEN downsell_flag = 1 AND previous_plan = 'plus'
                THEN 'basic'
            ELSE previous_plan
        END AS current_plan,

        CASE bill_period_months
            WHEN 1 THEN 0.00
            WHEN 3 THEN 0.05
            WHEN 6 THEN 0.10
        END::double precision AS discount

    FROM movement_signal m
),

economics AS (
    SELECT
        p.*,

        CASE current_plan
            WHEN 'basic' THEN 10.00
            WHEN 'plus' THEN 20.00
            WHEN 'premium' THEN 35.00
        END
        * (1.0 - discount) AS current_mrr,

        CASE previous_plan
            WHEN 'basic' THEN 10.00
            WHEN 'plus' THEN 20.00
            WHEN 'premium' THEN 35.00
        END
        * (1.0 - discount) AS previous_mrr

    FROM plan_movement p
),

movement_history AS (
    SELECT
        e.*,

        MAX(upgrade_flag) OVER (
            PARTITION BY account_id
            ORDER BY observation_date::timestamp
            RANGE BETWEEN INTERVAL '90 day' PRECEDING AND CURRENT ROW
        )::integer AS upgrade_last_90d,

        MAX(downsell_flag) OVER (
            PARTITION BY account_id
            ORDER BY observation_date::timestamp
            RANGE BETWEEN INTERVAL '90 day' PRECEDING AND CURRENT ROW
        )::integer AS downsell_last_90d

    FROM economics e
)

SELECT
    account_id,
    observation_date,

    previous_plan,
    current_plan,

    ROUND(current_mrr::numeric, 2)::double precision AS current_mrr,

    bill_period_months,
    discount,

    ROUND(
        (current_mrr - previous_mrr)::numeric,
        2
    )::double precision AS mrr_change,

    upgrade_flag,
    downsell_flag,
    upgrade_last_90d,
    downsell_last_90d

FROM movement_history

ORDER BY
    account_id,
    observation_date;


CREATE UNIQUE INDEX IF NOT EXISTS
    subscription_features_account_observation_idx
ON socialnet7.subscription_features
    (account_id, observation_date);


-- ------------------------------------------------------------
-- Validation
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT account_id) AS accounts,
    MIN(observation_date) AS first_observation,
    MAX(observation_date) AS last_observation
FROM socialnet7.subscription_features;


SELECT
    current_plan,
    COUNT(*) AS observations,
    ROUND(AVG(current_mrr)::numeric, 2) AS avg_mrr
FROM socialnet7.subscription_features
GROUP BY current_plan
ORDER BY current_plan;


SELECT
    bill_period_months,
    discount,
    COUNT(*) AS observations
FROM socialnet7.subscription_features
GROUP BY
    bill_period_months,
    discount
ORDER BY bill_period_months;
