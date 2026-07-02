USE UPI_Analysis;

SELECT TOP 20
    value                    AS word,
    COUNT(*)                 AS frequency
FROM dbo.reviews
CROSS APPLY STRING_SPLIT(LOWER(review_text), ' ')
WHERE rating <= 2
  AND LEN(TRIM(review_text)) >= 10
  AND LOWER(review_text) NOT LIKE '%deduct%'
  AND LOWER(review_text) NOT LIKE '%refund%'
  AND LOWER(review_text) NOT LIKE '%fraud%'
  AND LOWER(review_text) NOT LIKE '%crash%'
  AND LOWER(review_text) NOT LIKE '%customer care%'
  AND LOWER(review_text) NOT LIKE '%rbi%'
  AND LOWER(review_text) NOT LIKE '%slow%'
  AND LEN(value) > 3
GROUP BY value
ORDER BY frequency DESC;