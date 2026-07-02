-- ================================================
-- UPI Analysis -- SSMS Setup Script
-- Run this entire script in SSMS
-- ================================================

-- STEP 1: Create Database

USE master;
GO

IF NOT EXISTS (
    SELECT name 
    FROM sys.databases
    WHERE name = N'UPI_Analysis'
)
BEGIN
    CREATE DATABASE UPI_Analysis;
END
GO


USE UPI_Analysis;
GO


-- STEP 2: Create reviews table

DROP TABLE IF EXISTS dbo.reviews;

CREATE TABLE dbo.reviews (

    review_id    NVARCHAR(100),

    app          NVARCHAR(50),

    data_source  NVARCHAR(50),

    date         DATETIME,

    year         INT,

    year_month   NVARCHAR(10),

    rating       INT,

    review_text  NVARCHAR(MAX),

    thumbs_up    INT,

    reply_text   NVARCHAR(MAX),

    reply_date   DATETIME,

    user_name    NVARCHAR(200),

    app_version  NVARCHAR(50)

);

GO



-- STEP 3: Import CSV

-- UPDATE the path below to match your machine

BULK INSERT dbo.reviews

FROM 'C:\Users\kumar\Downloads\gold_master_export.csv'

WITH (

    FORMAT = 'CSV',

    FIRSTROW = 2,

    FIELDTERMINATOR = ',',

    ROWTERMINATOR = '0x0a',

    CODEPAGE = '65001',

    TABLOCK

);

GO



-- STEP 4: Verify import

SELECT

    app,

    COUNT(*) AS total_reviews,

    ROUND(
        AVG(CAST(rating AS FLOAT)),
        2
    ) AS avg_rating,

    MIN(date) AS earliest_review,

    MAX(date) AS latest_review

FROM dbo.reviews

GROUP BY app

ORDER BY app;

GO