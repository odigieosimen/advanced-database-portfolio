-- =====================================================================
-- Verify the data load (run after load_data.sql). Screenshot the results.
-- =====================================================================
USE olist_marketplace;

-- 1. Row count per table
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'sellers',              COUNT(*) FROM sellers
UNION ALL SELECT 'products',             COUNT(*) FROM products
UNION ALL SELECT 'orders',               COUNT(*) FROM orders
UNION ALL SELECT 'order_items',          COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments',       COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews',        COUNT(*) FROM order_reviews
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation
UNION ALL SELECT 'geolocation',          COUNT(*) FROM geolocation;

-- 2. Orders by status (should only show the 8 allowed statuses)
SELECT order_status, COUNT(*) AS orders
FROM orders GROUP BY order_status ORDER BY orders DESC;

-- 3. Spot-check: one order with its customer and items
SELECT o.order_id, o.order_status, c.customer_city, i.order_item_id, i.price
FROM orders o
JOIN customers c   ON c.customer_id = o.customer_id
JOIN order_items i ON i.order_id    = o.order_id
LIMIT 5;

-- 4. NULL handling: products with missing category, orders not yet delivered
SELECT COUNT(*) AS products_without_category
FROM products WHERE product_category_name IS NULL;

SELECT COUNT(*) AS orders_without_delivery_date
FROM orders WHERE order_delivered_customer_date IS NULL;

-- 5. Zip-code format check (should return 0 rows: every zip has 5 characters)
SELECT customer_zip_code_prefix FROM customers
WHERE CHAR_LENGTH(customer_zip_code_prefix) <> 5 LIMIT 5;
