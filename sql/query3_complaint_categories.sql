-- ============================================================
-- Query 3: Complaint Categories
-- Database : UPI_Analysis
-- Table    : dbo.reviews
-- ============================================================
--
-- BUSINESS QUESTION:
--   What are users actually complaining about?
--   Which complaint type dominates for each app?
--   This is the core of the decline analysis — not just THAT
--   ratings are low, but specifically WHY.
--
-- WHY THIS IS QUERY 3:
--   Query 1 told us the scale of negativity.
--   Query 2 told us when it happened.
--   Query 3 tells us what the actual complaints are.
--   This is the most important query for answering the
--   project question: "Why are these apps declining?"
--
-- COLUMNS USED:
--   review_text  -> CASE WHEN LIKE for keyword classification
--   rating       -> WHERE filter — only negative reviews (1-2 stars)
--   app          -> GROUP BY for per-app breakdown
--   review_id    -> COUNT for complaint volume
--
-- SQL OPERATIONS:
--   LOWER()         -> make keyword matching case-insensitive
--                      catches "FRAUD", "Fraud", "fraud" equally
--   CASE WHEN LIKE  -> classify each review into one complaint bucket
--   CTE (classified)-> separate classification logic from aggregation
--                      makes query readable and reusable
--   GROUP BY        -> count reviews per app per category
--   RANK() OVER     -> rank complaint types within each app
--                      so we know which is #1 complaint for each app
--
-- ⚠ SAMPLING BIAS NOTE:
--   Reviews from 2018-2022 come primarily from the Kaggle _help files
--   which were scraped sorted by "Most Helpful" on the Play Store.
--   Highly upvoted reviews tend to be detailed complaints, so
--   2018-2022 data is complaint-heavy by sampling design.
--   Reviews from 2023 onward (kaggle_new + fresh_scrape_2026)
--   are more balanced. Complaint category counts here reflect
--   the combined dataset — valid for identifying WHAT people
--   complain about, but volumes should not be taken as exact
--   proportions of all real-world users.
--
-- EXPECTED OUTPUT:
--   One row per app per complaint category showing count,
--   percentage of that app's negative reviews, and rank
-- ============================================================

USE UPI_Analysis;
GO

WITH classified AS (
    -- Step 1: Classify each negative review into one complaint category
    -- using keyword matching on review_text.
    -- LOWER() ensures case-insensitive matching.
    -- Order of WHEN clauses matters — first match wins.
    -- More specific categories come before broader ones.
    SELECT
        app,
        review_id,
        rating,
        year,
        CASE
            -- Payment failures: money movement issues
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

            -- Trust issues: fraud and security concerns
            WHEN LOWER(review_text) LIKE '%fraud%'
              OR LOWER(review_text) LIKE '%scam%'
              OR LOWER(review_text) LIKE '%cheat%'
              OR LOWER(review_text) LIKE '%hack%'
              OR LOWER(review_text) LIKE '%unauthori%'
              OR LOWER(review_text) LIKE '%stolen%'
              OR LOWER(review_text) LIKE '%fake%'
            THEN 'Trust & Security'

            -- Technical failures: app not working
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

            -- Customer support: no help when things go wrong
            WHEN LOWER(review_text) LIKE '%customer care%'
              OR LOWER(review_text) LIKE '%customer support%'
              OR LOWER(review_text) LIKE '%no response%'
              OR LOWER(review_text) LIKE '%not respond%'
              OR LOWER(review_text) LIKE '%helpline%'
              OR LOWER(review_text) LIKE '%no help%'
              OR LOWER(review_text) LIKE '%complaint%'
            THEN 'Customer Support'

            -- Regulatory: RBI, bank, KYC issues (Paytm specific)
            WHEN LOWER(review_text) LIKE '%rbi%'
              OR LOWER(review_text) LIKE '%kyc%'
              OR LOWER(review_text) LIKE '%account block%'
              OR LOWER(review_text) LIKE '%account suspend%'
              OR LOWER(review_text) LIKE '%paytm bank%'
              OR LOWER(review_text) LIKE '%payments bank%'
              OR LOWER(review_text) LIKE '%license%'
            THEN 'Regulatory Issues'

            -- UX problems: bad design and experience
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
        END AS complaint_category

    FROM dbo.reviews
    WHERE rating <= 2                      -- negative reviews only
      AND LEN(TRIM(review_text)) >= 10     -- exclude very short reviews
),

aggregated AS (
    -- Step 2: Count reviews per app per complaint category
    SELECT
        app,
        complaint_category,
        COUNT(review_id)                              AS complaint_count,

        -- What % of this app's negative reviews fall in this category?
        ROUND(
            100.0 * COUNT(review_id)
                  / SUM(COUNT(review_id)) OVER (PARTITION BY app),
        1)                                            AS pct_of_app_negatives
    FROM classified
    GROUP BY app, complaint_category
)

-- Step 3: Add rank so we know the #1 complaint per app
SELECT
    app,
    complaint_category,
    complaint_count,
    pct_of_app_negatives,
    RANK() OVER (
        PARTITION BY app
        ORDER BY complaint_count DESC
    )                                                 AS rank_within_app
FROM aggregated
ORDER BY app, rank_within_app;
GO
