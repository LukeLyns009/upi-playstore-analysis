-- ============================================================
-- Query 6: Era Comparison — Early vs Crisis vs Recovery
-- Database : UPI_Analysis
-- Table    : dbo.reviews
-- ============================================================
--
-- BUSINESS QUESTION:
--   How has user sentiment changed across three distinct eras?
--   Are complaints in 2026 different in nature from 2018?
--   Did the 2022-2023 crisis permanently damage user trust
--   or did things genuinely recover?
--   Which complaint types are era-specific vs persistent?
--
-- WHY THIS IS QUERY 6:
--   Queries 1-5 built the full picture piece by piece.
--   Query 6 steps back and looks at the complete arc —
--   where did these apps start, what went wrong, and
--   where do they stand today. This is the concluding
--   query that ties the entire analysis together.
--
-- ERA DEFINITIONS:
--   Early    → 2018-2019  First 2 years of mass UPI adoption
--   Crisis   → 2020-2022  COVID + fraud surge + regulatory pressure
--   Recovery → 2023-2026  Post-crisis stabilisation
--
-- COLUMNS USED:
--   year         -> CASE WHEN to define era buckets
--   rating       -> avg sentiment per era
--   review_text  -> same CASE WHEN as Query 3 and 4
--   thumbs_up    -> avg helpfulness votes per era
--   data_source  -> shown for transparency
--
-- SQL OPERATIONS:
--   CASE WHEN year    -> era bucketing
--   CASE WHEN LIKE    -> same complaint classification as Q3/Q4
--   SUM(CASE WHEN)    -> pivot complaint categories into columns
--   AVG + CAST        -> avg rating per era
--   RANK() OVER       -> top complaint per app per era
--   PCT calculation   -> complaint share within era negatives
--
-- ⚠ SAMPLING BIAS NOTE:
--   Reviews from 2018-2022 come primarily from the Kaggle _help
--   files which were scraped sorted by Most Helpful on Play Store.
--   Highly upvoted reviews tend to be detailed complaints, so
--   2018-2022 data is complaint-heavy by sampling design.
--   Recovery era (2023-2026) includes kaggle_new which is more
--   balanced. Direct era-to-era volume comparisons should be
--   treated as directional. Complaint TYPE comparisons across
--   eras are more reliable than absolute volume comparisons.
--
-- EXPECTED OUTPUT:
--   Part A — Sentiment overview per app per era
--   Part B — Complaint category breakdown per app per era
--   Part C — Top complaint per app per era (the headline finding)
-- ============================================================

USE UPI_Analysis;
GO

-- ============================================================
-- PART A: Sentiment overview across three eras
-- ============================================================
WITH era_sentiment AS (
    SELECT
        app,
        data_source,

        -- Define three eras
        CASE
            WHEN year BETWEEN 2018 AND 2019 THEN '1_Early (2018-2019)'
            WHEN year BETWEEN 2020 AND 2022 THEN '2_Crisis (2020-2022)'
            WHEN year BETWEEN 2023 AND 2026 THEN '3_Recovery (2023-2026)'
        END                                                 AS era,

        rating,
        thumbs_up,
        review_id

    FROM dbo.reviews
    WHERE year BETWEEN 2018 AND 2026
)

SELECT
    app,
    era,

    -- Volume
    COUNT(review_id)                                        AS total_reviews,

    -- Overall sentiment
    ROUND(AVG(CAST(rating AS FLOAT)), 2)                    AS avg_rating,

    -- Negative reviews (1-2 stars)
    COUNT(CASE WHEN rating <= 2 THEN 1 END)                 AS negative_count,
    ROUND(
        100.0 * COUNT(CASE WHEN rating <= 2 THEN 1 END)
              / COUNT(review_id),
    1)                                                      AS negative_pct,

    -- Positive reviews (4-5 stars)
    COUNT(CASE WHEN rating >= 4 THEN 1 END)                 AS positive_count,
    ROUND(
        100.0 * COUNT(CASE WHEN rating >= 4 THEN 1 END)
              / COUNT(review_id),
    1)                                                      AS positive_pct,

    -- Avg thumbs up per review — higher = more users agreed
    ROUND(AVG(CAST(thumbs_up AS FLOAT)), 1)                 AS avg_thumbs_up,

    -- Most common data source in this era
    MAX(data_source)                                        AS sample_data_source

FROM era_sentiment
WHERE era IS NOT NULL
GROUP BY app, era
ORDER BY app, era;
GO

-- ============================================================
-- PART B: Complaint category breakdown per era
-- Which complaint types dominated each era?
-- ============================================================
WITH era_classified AS (
    -- Step 1: Assign era and classify complaints
    -- Same CASE WHEN as Query 3 and 4 for consistency
    SELECT
        app,
        review_id,
        CASE
            WHEN year BETWEEN 2018 AND 2019 THEN '1_Early (2018-2019)'
            WHEN year BETWEEN 2020 AND 2022 THEN '2_Crisis (2020-2022)'
            WHEN year BETWEEN 2023 AND 2026 THEN '3_Recovery (2023-2026)'
        END                                                 AS era,

        CASE
            WHEN LOWER(review_text) LIKE '%money deduct%'
              OR LOWER(review_text) LIKE '%amount deduct%'
              OR LOWER(review_text) LIKE '%not received%'
              OR LOWER(review_text) LIKE '%not credited%'
              OR LOWER(review_text) LIKE '%transaction fail%'
              OR LOWER(review_text) LIKE '%payment fail%'
              OR LOWER(review_text) LIKE '%refund%'
              OR LOWER(review_text) LIKE '%money stuck%'
              OR LOWER(review_text) LIKE '%pending%'
            THEN 'Payment Failures'

            WHEN LOWER(review_text) LIKE '%fraud%'
              OR LOWER(review_text) LIKE '%scam%'
              OR LOWER(review_text) LIKE '%cheat%'
              OR LOWER(review_text) LIKE '%hack%'
              OR LOWER(review_text) LIKE '%unauthori%'
              OR LOWER(review_text) LIKE '%stolen%'
              OR LOWER(review_text) LIKE '%fake%'
            THEN 'Trust & Security'

            WHEN LOWER(review_text) LIKE '%crash%'
              OR LOWER(review_text) LIKE '%not working%'
              OR LOWER(review_text) LIKE '%not open%'
              OR LOWER(review_text) LIKE '%not load%'
              OR LOWER(review_text) LIKE '%error%'
              OR LOWER(review_text) LIKE '%bug%'
              OR LOWER(review_text) LIKE '%otp%'
              OR LOWER(review_text) LIKE '%login%'
              OR LOWER(review_text) LIKE '%server%'
            THEN 'Technical Failures'

            WHEN LOWER(review_text) LIKE '%customer care%'
              OR LOWER(review_text) LIKE '%customer support%'
              OR LOWER(review_text) LIKE '%no response%'
              OR LOWER(review_text) LIKE '%not respond%'
              OR LOWER(review_text) LIKE '%helpline%'
              OR LOWER(review_text) LIKE '%no help%'
              OR LOWER(review_text) LIKE '%complaint%'
            THEN 'Customer Support'

            WHEN LOWER(review_text) LIKE '%rbi%'
              OR LOWER(review_text) LIKE '%kyc%'
              OR LOWER(review_text) LIKE '%account block%'
              OR LOWER(review_text) LIKE '%account suspend%'
              OR LOWER(review_text) LIKE '%paytm bank%'
              OR LOWER(review_text) LIKE '%payments bank%'
              OR LOWER(review_text) LIKE '%license%'
            THEN 'Regulatory Issues'

            WHEN LOWER(review_text) LIKE '%slow%'
              OR LOWER(review_text) LIKE '%ads%'
              OR LOWER(review_text) LIKE '%advertisement%'
              OR LOWER(review_text) LIKE '%confus%'
              OR LOWER(review_text) LIKE '%difficult%'
              OR LOWER(review_text) LIKE '%complicated%'
              OR LOWER(review_text) LIKE '%useless%'
              OR LOWER(review_text) LIKE '%worst app%'
              OR LOWER(review_text) LIKE '%bad app%'
            THEN 'UX Problems'

            ELSE 'Other'
        END                                                 AS complaint_category

    FROM dbo.reviews
    WHERE rating <= 2
      AND LEN(TRIM(review_text)) >= 10
      AND year BETWEEN 2018 AND 2026
),

era_aggregated AS (
    -- Step 2: Count per app per era per category
    SELECT
        app,
        era,
        complaint_category,
        COUNT(review_id)                                    AS complaint_count,

        -- % within this app's era negatives
        ROUND(
            100.0 * COUNT(review_id)
                  / SUM(COUNT(review_id)) OVER (
                        PARTITION BY app, era
                    ),
        1)                                                  AS pct_of_era_negatives
    FROM era_classified
    WHERE era IS NOT NULL
    GROUP BY app, era, complaint_category
)

-- Step 3: Add rank within each app+era
SELECT
    app,
    era,
    complaint_category,
    complaint_count,
    pct_of_era_negatives,
    RANK() OVER (
        PARTITION BY app, era
        ORDER BY complaint_count DESC
    )                                                       AS rank_in_era
FROM era_aggregated
ORDER BY app, era, rank_in_era;
GO

-- ============================================================
-- PART C: Top complaint per app per era
-- One row per app per era showing ONLY the #1 specific complaint
-- 'Other' is excluded BEFORE ranking so rank 1 is always
-- a named actionable complaint type.
-- See Part B for the complete picture including Other.
-- ============================================================
WITH era_classified_c AS (
    SELECT
        app,
        review_id,
        CASE
            WHEN year BETWEEN 2018 AND 2019 THEN '1_Early (2018-2019)'
            WHEN year BETWEEN 2020 AND 2022 THEN '2_Crisis (2020-2022)'
            WHEN year BETWEEN 2023 AND 2026 THEN '3_Recovery (2023-2026)'
        END                                                 AS era,
        CASE
            WHEN LOWER(review_text) LIKE '%money deduct%'
              OR LOWER(review_text) LIKE '%amount deduct%'
              OR LOWER(review_text) LIKE '%not received%'
              OR LOWER(review_text) LIKE '%not credited%'
              OR LOWER(review_text) LIKE '%transaction fail%'
              OR LOWER(review_text) LIKE '%payment fail%'
              OR LOWER(review_text) LIKE '%refund%'
              OR LOWER(review_text) LIKE '%money stuck%'
              OR LOWER(review_text) LIKE '%pending%'
            THEN 'Payment Failures'
            WHEN LOWER(review_text) LIKE '%fraud%'
              OR LOWER(review_text) LIKE '%scam%'
              OR LOWER(review_text) LIKE '%cheat%'
              OR LOWER(review_text) LIKE '%hack%'
              OR LOWER(review_text) LIKE '%unauthori%'
              OR LOWER(review_text) LIKE '%stolen%'
              OR LOWER(review_text) LIKE '%fake%'
            THEN 'Trust & Security'
            WHEN LOWER(review_text) LIKE '%crash%'
              OR LOWER(review_text) LIKE '%not working%'
              OR LOWER(review_text) LIKE '%not open%'
              OR LOWER(review_text) LIKE '%not load%'
              OR LOWER(review_text) LIKE '%error%'
              OR LOWER(review_text) LIKE '%bug%'
              OR LOWER(review_text) LIKE '%otp%'
              OR LOWER(review_text) LIKE '%login%'
              OR LOWER(review_text) LIKE '%server%'
            THEN 'Technical Failures'
            WHEN LOWER(review_text) LIKE '%customer care%'
              OR LOWER(review_text) LIKE '%customer support%'
              OR LOWER(review_text) LIKE '%no response%'
              OR LOWER(review_text) LIKE '%not respond%'
              OR LOWER(review_text) LIKE '%helpline%'
              OR LOWER(review_text) LIKE '%no help%'
              OR LOWER(review_text) LIKE '%complaint%'
            THEN 'Customer Support'
            WHEN LOWER(review_text) LIKE '%rbi%'
              OR LOWER(review_text) LIKE '%kyc%'
              OR LOWER(review_text) LIKE '%account block%'
              OR LOWER(review_text) LIKE '%account suspend%'
              OR LOWER(review_text) LIKE '%paytm bank%'
              OR LOWER(review_text) LIKE '%payments bank%'
              OR LOWER(review_text) LIKE '%license%'
            THEN 'Regulatory Issues'
            WHEN LOWER(review_text) LIKE '%slow%'
              OR LOWER(review_text) LIKE '%ads%'
              OR LOWER(review_text) LIKE '%advertisement%'
              OR LOWER(review_text) LIKE '%confus%'
              OR LOWER(review_text) LIKE '%difficult%'
              OR LOWER(review_text) LIKE '%complicated%'
              OR LOWER(review_text) LIKE '%useless%'
              OR LOWER(review_text) LIKE '%worst app%'
              OR LOWER(review_text) LIKE '%bad app%'
            THEN 'UX Problems'
            ELSE 'Other'
        END                                                 AS complaint_category
    FROM dbo.reviews
    WHERE rating <= 2
      AND LEN(TRIM(review_text)) >= 10
      AND year BETWEEN 2018 AND 2026
),

aggregated_c AS (
    SELECT
        app,
        era,
        complaint_category,
        COUNT(review_id)                                    AS complaint_count,
        ROUND(
            100.0 * COUNT(review_id)
                  / SUM(COUNT(review_id)) OVER (
                        PARTITION BY app, era
                    ),
        1)                                                  AS pct_of_era_negatives
    FROM era_classified_c
    WHERE era IS NOT NULL
      AND complaint_category != 'Other'
    GROUP BY app, era, complaint_category
),

ranked_c AS (
    SELECT
        app,
        era,
        complaint_category,
        complaint_count,
        pct_of_era_negatives,
        RANK() OVER (
            PARTITION BY app, era
            ORDER BY complaint_count DESC
        )                                                   AS rnk
    FROM aggregated_c
)

SELECT
    app,
    era,
    complaint_category                                      AS top_complaint,
    complaint_count,
    pct_of_era_negatives                                    AS pct_of_negatives
FROM ranked_c
WHERE rnk = 1
ORDER BY app, era;
GO
