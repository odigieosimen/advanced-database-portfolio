-- =====================================================================
-- Run this in EVERY session (Session A and Session B) before a demo.
-- User variables belong to one session, so both sessions need their own.
--   @p  = the first product in product_stock
--   @p2 = the second product (used by the deadlock demo)
-- =====================================================================
USE olist_marketplace;
SET @p  = (SELECT MIN(product_id) FROM product_stock);
SET @p2 = (SELECT product_id FROM product_stock ORDER BY product_id LIMIT 1 OFFSET 1);
SELECT @p AS product_1, @p2 AS product_2,
       @@transaction_isolation AS isolation_level,
       @@autocommit AS autocommit_on;
