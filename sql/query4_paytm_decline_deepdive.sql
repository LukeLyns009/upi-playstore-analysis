-- ============================================================
-- Query 4: Paytm Decline Deep Dive
-- Database : UPI_Analysis
-- Table    : dbo.reviews
-- ============================================================
--
-- BUSINESS QUESTION:
--   For Paytm specifically — how did complaints evolve
--   month by month? Did any complaint type spike at a
--   specific point in time indicating a specific event?
--   How does Paytm's complaint profile compare to PhonePe
--   as a baseline — is the decline Paytm-specific or
--   an industry-wide trend?
--
-- WHY THIS IS QUERY 4:
--   Query 3 showed WHAT people complain about.
--   Query 4 zooms into Paytm and asks WHEN complaints
--   spiked and WHETHER it was unique to Paytm.
--   This is the most critical query for answering the
--   project question about Paytm's specific decline.
--
-- COLUMNS USED:
--   app          -> filter to Paytm and PhonePe
--   year_month   -> monthly GROUP BY for granular timeline
--   review_text  -> same CASE WHEN as Query 3 (consistent)
--   rating       -> WHERE <= 2 negative reviews only
--   review_id    -> COUNT for volume
--
-- SQL OPERATIONS:
--   CTE (classified)   -> same keyword classification as Query 3
--   CTE (monthly)      -> aggregate by app + year_month
--   PIVOT-style CASE   -> spread complaint categories into columns
--                         so each month is one readable row
--   SUM() OVER         -> running total of negative reviews
--                         shows cumulative complaint growth
--
-- ⚠ SAMPLING BIAS NOTE:
--   Reviews from 2018-2022 come primarily from the Kaggle _help files
--   which were scraped sorted by "Most Helpful" on the Play Store.
--   Highly upvoted reviews tend to be detailed complaints, so
--   2018-2022 data is complaint-heavy by sampling design.
--   Reviews from 2023 onward (kaggle_new + fresh_scrape_2026)
--   are more balanced. Month-by-month counts here reflect the
--   combined dataset — valid for identifying complaint patterns
--   but absolute volumes should not be read as exact proportions
--   of all real-world users.
--
-- EXPECTED OUTPUT:
--   One row per month per app showing total negative reviews,
--   breakdown by complaint category, and running total
-- ============================================================

USE UPI_Analysis;
GO

WITH classified AS (
    -- Step 1: Classify negative reviews — same logic as Query 3
    -- Keeping classification identical ensures consistency
    -- across all queries in this project
    SELECT
        app,
        year_month,
        year,
        review_id,
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
        END AS complaint_category

    FROM dbo.reviews
    WHERE rating <= 2
      AND LEN(TRIM(review_text)) >= 10
      AND app IN ('Paytm', 'PhonePe')    -- Paytm + PhonePe as baseline
),

monthly AS (
    -- Step 2: Aggregate by app and month
    -- Spread complaint categories into columns using CASE WHEN inside SUM
    -- so each month is one readable row instead of 7 rows
    SELECT
        app,
        year_month,
        year,
        COUNT(review_id)                                        AS total_negative,

        -- Complaint category columns
        SUM(CASE WHEN complaint_category = 'Payment Failures'  THEN 1 ELSE 0 END) AS payment_failures,
        SUM(CASE WHEN complaint_category = 'Trust & Security'  THEN 1 ELSE 0 END) AS trust_security,
        SUM(CASE WHEN complaint_category = 'Technical Failures'THEN 1 ELSE 0 END) AS technical_failures,
        SUM(CASE WHEN complaint_category = 'Customer Support'  THEN 1 ELSE 0 END) AS customer_support,
        SUM(CASE WHEN complaint_category = 'Regulatory Issues' THEN 1 ELSE 0 END) AS regulatory_issues,
        SUM(CASE WHEN complaint_category = 'UX Problems'       THEN 1 ELSE 0 END) AS ux_problems,
        SUM(CASE WHEN complaint_category = 'Other'             THEN 1 ELSE 0 END) AS other_complaints

    FROM classified
    GROUP BY app, year_month, year
)

-- Step 3: Add running total of negative reviews per app
-- This shows cumulative complaint growth over time
SELECT
    app,
    year_month,
    total_negative,
    payment_failures,
    trust_security,
    technical_failures,
    customer_support,
    regulatory_issues,
    ux_problems,
    other_complaints,

    -- Running total within each app ordered by month
    SUM(total_negative) OVER (
        PARTITION BY app
        ORDER BY year_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                           AS running_total_negative

FROM monthly
ORDER BY app, year_month;
GO
