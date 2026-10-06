WITH
date_range AS (
    SELECT
        '2020-01-01'::timestamp AS start_date,
        '2020-12-31'::timestamp AS end_date
),

account_count AS (
    SELECT
        COUNT(DISTINCT s.account_id) AS n_account
    FROM socialnet7.subscription s
    INNER JOIN date_range d
        ON s.start_date <= d.end_date
        AND (
            s.end_date >= d.start_date
            OR s.end_date IS NULL
        )
)

SELECT
    t.event_type_name,

    COUNT(*) AS n_event,

    ac.n_account,

    COUNT(*)::float
        / NULLIF(ac.n_account, 0)::float
        AS events_per_account,

    EXTRACT(
        DAYS FROM d.end_date - d.start_date
    )::float / 28.0
        AS n_months,

    (
        COUNT(*)::float
        / NULLIF(ac.n_account, 0)::float
    )
    /
    NULLIF(
        EXTRACT(
            DAYS FROM d.end_date - d.start_date
        )::float / 28.0,
        0
    )
        AS events_per_account_per_month

FROM socialnet7.event e

CROSS JOIN account_count ac

INNER JOIN socialnet7.event_type t
    ON t.event_type_id = e.event_type_id

INNER JOIN date_range d
    ON e.event_time >= d.start_date
    AND e.event_time <= d.end_date

GROUP BY
    e.event_type_id,
    t.event_type_name,
    ac.n_account,
    d.start_date,
    d.end_date

ORDER BY
    events_per_account_per_month DESC;

-- Output
--  event_type_name | n_event | n_account | events_per_account |      n_months      | events_per_account_per_month 
-- -----------------+---------+-----------+--------------------+--------------------+------------------------------
--  like            | 5795628 |     14641 |  395.8491906290554 | 13.035714285714286 |           30.366513253735754
--  message         | 3790278 |     14641 | 258.88108735742094 | 13.035714285714286 |           19.859371084952837
--  post            | 2376684 |     14641 | 162.33071511508777 | 13.035714285714286 |           12.452767186910842
--  adview          | 2375323 |     14641 | 162.23775698381257 | 13.035714285714286 |           12.445636152182882
--  reply           | 1384526 |     14641 |  94.56498873027799 | 13.035714285714286 |            7.254300505336393
--  dislike         |  962207 |     14641 |  65.72003278464585 | 13.035714285714286 |            5.041536761561873
--  newfriend       |  411657 |     14641 |  28.11672699952189 | 13.035714285714286 |            2.156899605442775
--  unfriend        |   19580 |     14641 | 1.3373403456048085 | 13.035714285714286 |          0.10259049226557435
-- (8 rows)