-- =====================================================================
-- Same 8 queries wrapped in EXPLAIN ANALYZE, for use in the mysql
-- command-line client (the \G ending prints the full plan as text).
-- Usage (see P2 README):  source <path>/explain_queries.sql
-- =====================================================================
USE olist_marketplace;

SELECT '=== Q1: Canceled orders per month in 2018 (filter on status + date range, then group) ===' AS label;
EXPLAIN ANALYZE
SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS order_month,
       COUNT(*) AS canceled_orders
FROM orders
WHERE order_status = 'canceled'
  AND order_purchase_timestamp >= '2018-01-01'
  AND order_purchase_timestamp <  '2019-01-01'
GROUP BY order_month
ORDER BY order_month\G

SELECT '=== Q2: Top 10 cities in Sao Paulo state by number of orders (filter + join + group) ===' AS label;
EXPLAIN ANALYZE
SELECT c.customer_city, COUNT(o.order_id) AS orders
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE c.customer_state = 'SP'
GROUP BY c.customer_city
ORDER BY orders DESC
LIMIT 10\G

SELECT '=== Q3: Revenue by product category, top 10 (3-table join over ALL order items: control query) ===' AS label;
EXPLAIN ANALYZE
SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
       ROUND(SUM(i.price), 2) AS revenue,
       COUNT(*) AS items_sold
FROM order_items i
JOIN products p ON p.product_id = i.product_id
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
GROUP BY category
ORDER BY revenue DESC
LIMIT 10\G

SELECT '=== Q4: One-star reviews per month (low-selectivity filter, candidate for a covering index) ===' AS label;
EXPLAIN ANALYZE
SELECT DATE_FORMAT(review_creation_date, '%Y-%m') AS review_month,
       COUNT(*) AS one_star_reviews
FROM order_reviews
WHERE review_score = 1
GROUP BY review_month
ORDER BY review_month\G

SELECT '=== Q5: Average coordinates for one zip code (point lookup in the 1M-row geolocation table) ===' AS label;
EXPLAIN ANALYZE
SELECT COUNT(*) AS points,
       ROUND(AVG(geolocation_lat), 5) AS avg_lat,
       ROUND(AVG(geolocation_lng), 5) AS avg_lng
FROM geolocation
WHERE geolocation_zip_code_prefix = '01151'\G

SELECT '=== Q6: Average coordinates for every seller in Rio de Janeiro state (join to geolocation) ===' AS label;
EXPLAIN ANALYZE
SELECT s.seller_id, s.seller_city,
       COUNT(*) AS points,
       ROUND(AVG(g.geolocation_lat), 4) AS avg_lat,
       ROUND(AVG(g.geolocation_lng), 4) AS avg_lng
FROM sellers s
JOIN geolocation g ON g.geolocation_zip_code_prefix = s.seller_zip_code_prefix
WHERE s.seller_state = 'RJ'
GROUP BY s.seller_id, s.seller_city\G

SELECT '=== Q7: Top 3 sellers by revenue in each state (CTE + window function RANK) ===' AS label;
EXPLAIN ANALYZE
WITH seller_revenue AS (
    SELECT s.seller_state, s.seller_id, SUM(i.price) AS revenue
    FROM order_items i
    JOIN sellers s ON s.seller_id = i.seller_id
    GROUP BY s.seller_state, s.seller_id
)
SELECT seller_state, seller_id, ROUND(revenue, 2) AS revenue, revenue_rank
FROM (
    SELECT seller_state, seller_id, revenue,
           RANK() OVER (PARTITION BY seller_state ORDER BY revenue DESC) AS revenue_rank
    FROM seller_revenue
) ranked
WHERE revenue_rank <= 3
ORDER BY seller_state, revenue_rank\G

SELECT '=== Q8: How many customers placed 1, 2, 3... orders (group on customer_unique_id) ===' AS label;
EXPLAIN ANALYZE
SELECT orders_per_customer, COUNT(*) AS customers
FROM (
    SELECT c.customer_unique_id, COUNT(*) AS orders_per_customer
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
) per_customer
GROUP BY orders_per_customer
ORDER BY orders_per_customer\G
