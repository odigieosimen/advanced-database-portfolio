-- =====================================================================
-- Evidence queries that justify the design decisions in the P1 README.
-- Run after load_data.sql.
-- =====================================================================
USE olist_marketplace;

-- A. Why review_id alone cannot be the primary key
--    (total rows > distinct review_ids, so review_id repeats)
SELECT COUNT(*)                  AS total_rows,
       COUNT(DISTINCT review_id) AS distinct_review_ids
FROM order_reviews;

-- B. Why category_translation has no foreign key
--    (categories used by products that have no English translation)
SELECT DISTINCT p.product_category_name
FROM products p
LEFT JOIN category_translation t
       ON t.product_category_name = p.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL;

-- C. Why geolocation has no foreign key
--    (customer zip codes with no row in geolocation)
SELECT COUNT(DISTINCT c.customer_zip_code_prefix) AS customer_zips_missing_from_geolocation
FROM customers c
LEFT JOIN (SELECT DISTINCT geolocation_zip_code_prefix AS z FROM geolocation) g
       ON g.z = c.customer_zip_code_prefix
WHERE g.z IS NULL;
