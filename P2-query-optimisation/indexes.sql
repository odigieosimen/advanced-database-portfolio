-- =====================================================================
-- MIT 8103 Portfolio 2: indexes added after the baseline measurements.
-- Each index targets one of the queries in queries.sql.
-- Note the time each CREATE INDEX takes (Output panel) for the write-up.
-- =====================================================================
USE olist_marketplace;

-- Q1: equality on status, then range on date. Also covers the query
--     (both columns it reads are in the index), so no table lookups.
CREATE INDEX idx_orders_status_purchase
    ON orders (order_status, order_purchase_timestamp);

-- Q2: equality filter on state; city is the next column the query needs.
CREATE INDEX idx_customers_state_city
    ON customers (customer_state, customer_city);

-- Q8: grouping on the real person's id. The primary key (customer_id)
--     is stored inside every secondary index, so this also covers the join.
CREATE INDEX idx_customers_unique
    ON customers (customer_unique_id);

-- Q4: score is a low-selectivity filter, but adding the date makes the
--     index cover the whole query.
CREATE INDEX idx_reviews_score_created
    ON order_reviews (review_score, review_creation_date);

-- Q5 and Q6: zip-code lookups in the 1M-row table. Latitude and longitude
--     are included so the averages are computed from the index alone.
CREATE INDEX idx_geo_zip_coords
    ON geolocation (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng);

-- Q7: revenue per seller. price is included so the sums come from the index.
CREATE INDEX idx_items_seller_price
    ON order_items (seller_id, price);

-- Q3 deliberately gets no new index: it aggregates every order item, so an
-- index is not expected to help. This is the control query.

-- Refresh optimiser statistics so the plans use the new indexes sensibly.
ANALYZE TABLE orders, customers, order_reviews, geolocation, order_items;

-- Storage cost of every index (MB). Screenshot this for the write-up.
SELECT table_name, index_name,
       ROUND(stat_value * @@innodb_page_size / 1024 / 1024, 2) AS size_mb
FROM mysql.innodb_index_stats
WHERE database_name = 'olist_marketplace'
  AND stat_name = 'size'
ORDER BY size_mb DESC;
