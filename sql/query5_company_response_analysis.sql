-- ============================================================
-- Query 5: Company Response Analysis
-- Database : UPI_Analysis
-- Table    : dbo.reviews
-- ============================================================
--
-- BUSINESS QUESTION:
--   Do these apps respond to negative reviews?
--   Which app has the highest response rate?
--   Does getting a reply correlate with better user ratings?
--   How quickly do companies respond when they do reply?
--   Could poor response rates be contributing to Paytm's
--   declining user satisfaction?
--
-- WHY THIS IS QUERY 5:
--   Queries 1-4 told us WHAT users complain about and WHEN.
--   Query 5 asks WHETHER the companies are even listening.
--   A company that ignores negative reviews signals to users
--   that their complaints don't matter — which compounds
--   the frustration and accelerates decline.
--
-- COLUMNS USED:
--   reply_text   -> IS NULL / IS NOT NULL to detect replies
--   reply_date   -> to calculate response time
--   date         -> combined with reply_date for DATEDIFF
--   rating       -> avg rating replied vs not replied
--   app          -> GROUP BY
--   data_source  -> filter to Kaggle only (has reply data)
--
-- SQL OPERATIONS:
--   WHERE data_source  -> Kaggle files only — fresh scrape
--                         has no reply_text column populated
--   CASE WHEN IS NULL  -> classify each review as replied/not
--   DATEDIFF()         -> T-SQL function: days between dates
--   AVG with CASE      -> split avg rating by reply status
--   CTE (response)     -> flag each review with reply status
--   CTE (summary)      -> aggregate response stats per app
--   RANK() OVER        -> rank apps by response rate
--
-- ⚠ SAMPLING BIAS NOTE:
--   Reviews from 2018-2022 come primarily from the Kaggle _help
--   files which were scraped sorted by Most Helpful on Play Store.
--   Companies may be more likely to reply to highly upvoted
--   complaints visible to more users than to average reviews.
--   So response rates here may be higher than the true average
--   across all reviews. Treat these as directional not exact.
--
-- EXPECTED OUTPUT:
--   Part A — Response rate and avg rating by app
--   Part B — Response rate by year per app
-- ============================================================

USE UPI_Analysis;
GO

-- ============================================================
-- PART A: Response rate and overall stats per app
-- ============================================================
WITH response_flags AS (
    -- Step 1: Flag each review as replied or not
    -- Also calculate response time where reply exists
    SELECT
        app,
        review_id,
        rating,
        date,
        reply_text,
        reply_date,

        -- Did the company reply?
        CASE
            WHEN reply_text IS NOT NULL
             AND LEN(TRIM(CAST(reply_text AS NVARCHAR(MAX)))) > 0
            THEN 1
            ELSE 0
        END                                             AS was_replied,

        -- How many days did it take to reply?
        CASE
            WHEN reply_text IS NOT NULL
             AND reply_date IS NOT NULL
             AND TRY_CAST(reply_date AS DATETIME) IS NOT NULL
             AND TRY_CAST(date AS DATETIME) IS NOT NULL
             AND CAST(reply_date AS DATETIME) > CAST(date AS DATETIME)
            THEN DATEDIFF(
                    day,
                    CAST(date AS DATETIME),
                    CAST(reply_date AS DATETIME)
                 )
            ELSE NULL
        END                                             AS days_to_reply

    FROM dbo.reviews
    WHERE data_source IN ('kaggle_help', 'kaggle_new')
),

app_summary AS (
    -- Step 2: Aggregate response stats per app
    SELECT
        app,
        COUNT(review_id)                                AS total_reviews,
        SUM(was_replied)                                AS replied_count,
        ROUND(
            100.0 * SUM(was_replied) / COUNT(review_id),
        1)                                              AS response_rate_pct,
        ROUND(AVG(CAST(rating AS FLOAT)), 2)            AS avg_rating_all,
        ROUND(AVG(
            CASE WHEN was_replied = 1
                 THEN CAST(rating AS FLOAT) END
        ), 2)                                           AS avg_rating_replied,
        ROUND(AVG(
            CASE WHEN was_replied = 0
                 THEN CAST(rating AS FLOAT) END
        ), 2)                                           AS avg_rating_not_replied,
        ROUND(AVG(CAST(days_to_reply AS FLOAT)), 1)     AS avg_days_to_reply,
        MIN(days_to_reply)                              AS min_days_to_reply,
        MAX(days_to_reply)                              AS max_days_to_reply
    FROM response_flags
    GROUP BY app
)

SELECT
    app,
    total_reviews,
    replied_count,
    response_rate_pct,
    avg_rating_all,
    avg_rating_replied,
    avg_rating_not_replied,
    ROUND(avg_rating_replied - avg_rating_not_replied, 2) AS reply_impact_on_rating,
    avg_days_to_reply,
    min_days_to_reply,
    max_days_to_reply,
    RANK() OVER (ORDER BY response_rate_pct DESC)       AS response_rank
FROM app_summary
ORDER BY response_rate_pct DESC;
GO

-- ============================================================
-- PART B: Response rate broken down by year
-- Did response rates change over time?
-- ============================================================
SELECT
    app,
    year,
    COUNT(review_id)                                    AS total_reviews,
    SUM(
        CASE
            WHEN reply_text IS NOT NULL
             AND LEN(TRIM(CAST(reply_text AS NVARCHAR(MAX)))) > 0
            THEN 1 ELSE 0
        END
    )                                                   AS replied_count,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN reply_text IS NOT NULL
                 AND LEN(TRIM(CAST(reply_text AS NVARCHAR(MAX)))) > 0
                THEN 1 ELSE 0
            END
        ) / COUNT(review_id),
    1)                                                  AS response_rate_pct,
    ROUND(
        (100.0 * SUM(
            CASE
                WHEN reply_text IS NOT NULL
                 AND LEN(TRIM(CAST(reply_text AS NVARCHAR(MAX)))) > 0
                THEN 1 ELSE 0
            END
        ) / COUNT(review_id))
        -
        LAG(
            100.0 * SUM(
                CASE
                    WHEN reply_text IS NOT NULL
                     AND LEN(TRIM(CAST(reply_text AS NVARCHAR(MAX)))) > 0
                    THEN 1 ELSE 0
                END
            ) / COUNT(review_id),
            1
        ) OVER (PARTITION BY app ORDER BY year),
    1)                                                  AS response_rate_change
FROM dbo.reviews
WHERE data_source IN ('kaggle_help', 'kaggle_new')
  AND year BETWEEN 2018 AND 2023
GROUP BY app, year
ORDER BY app, year;
GO