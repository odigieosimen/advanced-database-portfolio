-- =====================================================================
-- Returns the demo data to its starting state (10 units of every product,
-- no demo orders). Run between demos, from any session.
-- =====================================================================
USE olist_marketplace;
DELETE FROM order_items WHERE order_id LIKE 'p3demo%';
DELETE FROM orders      WHERE order_id LIKE 'p3demo%';
UPDATE product_stock SET quantity = 10;
SELECT product_id, quantity FROM product_stock ORDER BY product_id;
