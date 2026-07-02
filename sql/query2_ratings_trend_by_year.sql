-- ============================================================
-- Query 2: Rating Trend by Year
-- Database : UPI_Analysis
-- Table    : dbo.reviews
-- ============================================================
--
-- BUSINESS QUESTION:
--   Have ratings been getting worse over time?
--   Which year was the worst for each app?
--   Is the decline consistent year on year or did it spike
--   in a specific year?
--
-- WHY THIS MATTERS:
--   Query 1 gave us the overall picture.
--   Query 2 shows us WHEN things changed.
--   If we see a sharp drop in a specific year, that points
--   to a specific event (e.g. Paytm RBI action, GPay outages).
--   This is the time-series backbone of the decline story.
--
-- COLUMNS USED:
--   app         -> GROUP BY
--   year        -> GROUP BY for time axis
--   rating      -> AVG per year
--   review_id   -> COUNT for volume confidence
--
-- SQL OPERATIONS:
--   GROUP BY app, year     -> one row per app per year
--   AVG + CAST             -> average rating per year
--   LAG() OVER             -> compare to previous year's rating
--   rating_change          -> calculated column showing YoY movement
--   CASE WHEN              -> label direction as IMPROVED/DECLINED/STABLE
--
-- NOTE ON LAG():
--   LAG(avg_rating, 1) OVER (PARTITION BY app ORDER BY year)
--   This looks at the previous row within the same app partition.
--   PARTITION BY app ensures GPay compares to GPay only,
--   not to the last row of Paytm.
--
-- EXPECTED OUTPUT:
--   One row per app per year showing avg rating, review count,
--   previous year rating, change, and direction label
-- ============================================================

USE UPI_Analysis;
GO

WITH yearly_ratings AS (
    -- Step 1: Calculate avg rating and volume per app per year
    SELECT
        app,
        year,
        COUNT(review_id)                        AS review_count,
        ROUND(AVG(CAST(rating AS FLOAT)), 2)    AS avg_rating
    FROM dbo.reviews
    WHERE year BETWEEN 2018 AND 2026
    GROUP BY app, year
),

yearly_with_lag AS (
    -- Step 2: Use LAG() to bring in the previous year's rating
    -- PARTITION BY app so each app has its own independent timeline
    SELECT
        app,
        year,
        review_count,
        avg_rating,
        LAG(avg_rating, 1) OVER (
            PARTITION BY app
            ORDER BY year
        )                                       AS prev_year_rating
    FROM yearly_ratings
)

-- Step 3: Calculate year-on-year change and label direction
SELECT
    app,
    year,
    review_count,
    avg_rating,
    prev_year_rating,

    -- How much did the rating change vs last year?
    ROUND(avg_rating - prev_year_rating, 2)     AS rating_change,

    -- Label the direction clearly
    CASE
        WHEN prev_year_rating IS NULL               THEN 'BASELINE'
        WHEN avg_rating > prev_year_rating + 0.05   THEN 'IMPROVED'
        WHEN avg_rating < prev_year_rating - 0.05   THEN 'DECLINED'
        ELSE                                             'STABLE'
    END                                         AS direction

FROM yearly_with_lag
ORDER BY app, year;
GO
