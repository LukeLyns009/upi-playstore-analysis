-- ============================================================
-- Query 1: Ratings Overview
-- Database : UPI_Analysis
-- Table    : dbo.reviews
-- ============================================================
--
-- BUSINESS QUESTION:
--   What is the overall rating picture for each app?
--   How do GPay, Paytm, and PhonePe compare against each other?
--   What share of reviews are negative vs positive?
--
-- WHY THIS IS QUERY 1:
--   Before we dig into WHY users are unhappy, we first need to
--   establish WHAT the numbers look like at a high level.
--   This is the foundation every other query builds on top of.
--
-- COLUMNS USED:
--   app         -> GROUP BY to get one row per app
--   rating      -> AVG for overall score, CASE WHEN for bucketing
--   review_id   -> COUNT for total volume
--
-- SQL OPERATIONS:
--   GROUP BY    -> aggregate per app
--   AVG + CAST  -> rating is INT so we CAST to FLOAT before averaging
--   CASE WHEN   -> bucket ratings into negative (1-2), neutral (3), positive (4-5)
--   ROUND       -> clean up decimal places in output
--
-- EXPECTED OUTPUT:
--   One row per app with:
--   total_reviews, avg_rating, negative_count, neutral_count,
--   positive_count, negative_pct, positive_pct
-- ============================================================

USE UPI_Analysis;
GO

SELECT
    app,

    -- Total volume
    COUNT(review_id)                                        AS total_reviews,

    -- Overall average rating
    ROUND(AVG(CAST(rating AS FLOAT)), 2)                    AS avg_rating,

    -- Negative reviews (1-2 stars) — users who are clearly unhappy
    COUNT(CASE WHEN rating <= 2 THEN 1 END)                 AS negative_count,

    -- Neutral reviews (3 stars) — sitting on the fence
    COUNT(CASE WHEN rating = 3  THEN 1 END)                 AS neutral_count,

    -- Positive reviews (4-5 stars) — satisfied users
    COUNT(CASE WHEN rating >= 4 THEN 1 END)                 AS positive_count,

    -- Negative % — key decline indicator
    ROUND(
        100.0 * COUNT(CASE WHEN rating <= 2 THEN 1 END)
              / COUNT(review_id),
    1)                                                      AS negative_pct,

    -- Positive % — for comparison
    ROUND(
        100.0 * COUNT(CASE WHEN rating >= 4 THEN 1 END)
              / COUNT(review_id),
    1)                                                      AS positive_pct

FROM dbo.reviews

GROUP BY app
ORDER BY avg_rating ASC;   -- worst rated app appears first
GO
