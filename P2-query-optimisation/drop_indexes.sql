-- =====================================================================
-- Removes the P2 indexes, returning the database to its baseline state.
-- Run only if the indexes exist (MySQL gives an error for a missing index).
-- =====================================================================
USE olist_marketplace;

DROP INDEX idx_orders_status_purchase ON orders;
DROP INDEX idx_customers_state_city   ON customers;
DROP INDEX idx_customers_unique       ON customers;
DROP INDEX idx_reviews_score_created  ON order_reviews;
DROP INDEX idx_geo_zip_coords         ON geolocation;
DROP INDEX idx_items_seller_price     ON order_items;
