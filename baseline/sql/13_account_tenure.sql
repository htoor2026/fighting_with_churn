WITH RECURSIVE

date_vals AS (
    SELECT i::timestamp AS metric_date
    FROM generate_series(
        '2020-02-02'::timestamp,
        '2020-05-10'::timestamp,
        '7 day'::interval
    ) AS i
),

earlier_starts AS (

    /* Anchor query:
       For every metric date, find subscriptions active on that date.
    */
    SELECT
        s.account_id,
        d.metric_date,
        MIN(s.start_date) AS start_date

    FROM socialnet7.subscription s

    INNER JOIN date_vals d
        ON s.start_date <= d.metric_date
        AND (
            s.end_date > d.metric_date
            OR s.end_date IS NULL
        )

    GROUP BY
        s.account_id,
        d.metric_date


    UNION


    /* Recursive query:
       Search backward for earlier connected subscriptions.
    */
    SELECT
        s.account_id,
        e.metric_date,
        s.start_date

    FROM socialnet7.subscription s

    INNER JOIN earlier_starts e
        ON s.account_id = e.account_id
        AND s.start_date < e.start_date
        AND s.end_date >= (e.start_date - 31)
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
    e.metric_date,
    8 AS metric_name_id,
    EXTRACT(
        DAYS FROM e.metric_date - MIN(e.start_date)
    ) AS metric_value

FROM earlier_starts e

GROUP BY
    e.account_id,
    e.metric_date

ORDER BY
    e.account_id,
    e.metric_date;

--  Output

-- INSERT 0 165176