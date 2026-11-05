-- =====================================================================
-- MIT 8103 Portfolio 4: export the case study data as JSON for MongoDB
-- Run in MySQL Workbench. Each statement writes one JSON document per line
-- (newline-delimited JSON) into MySQL's import/export folder.
--
-- BEFORE RUNNING:
--  * If your folder differs from the path below, use Find & Replace on
--      C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/
--  * MySQL refuses to overwrite a file: delete any earlier nosql_*.json first.
--  * ESCAPED BY '' is deliberate: it stops MySQL doubling the backslashes
--    that JSON needs.
--  * Dates are written as Extended JSON ({"$date": ...}) so MongoDB stores
--    real dates, not text. Times are treated as UTC.
-- The orders export takes a few minutes on a slow machine.
-- =====================================================================
USE olist_marketplace;

-- ---------- 1. products (all rows): one document per product ----------
SELECT JSON_OBJECT(
  '_id', p.product_id,
  'category', JSON_OBJECT('pt', p.product_category_name,
                          'en', t.product_category_name_english),
  'dimensions', JSON_OBJECT('length_cm', p.product_length_cm,
                            'height_cm', p.product_height_cm,
                            'width_cm',  p.product_width_cm,
                            'weight_g',  p.product_weight_g),
  'photos_qty', p.product_photos_qty,
  'name_length', p.product_name_length,
  'description_length', p.product_description_length
)
FROM products p
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/nosql_products.json'
CHARACTER SET utf8mb4
FIELDS TERMINATED BY '' ESCAPED BY ''
LINES TERMINATED BY '\n';

-- ---------- 2. sellers (all rows) ----------
SELECT JSON_OBJECT(
  '_id', seller_id,
  'zip_prefix', seller_zip_code_prefix,
  'city', seller_city,
  'state', seller_state
)
FROM sellers
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/nosql_sellers.json'
CHARACTER SET utf8mb4
FIELDS TERMINATED BY '' ESCAPED BY ''
LINES TERMINATED BY '\n';

-- ---------- 3. orders: ONE document holding the order, its customer,
--            items, payments and reviews (a sample of 20,000 orders) ----------
-- To export every order, delete the LIMIT line (about 5 times the data).
SELECT JSON_OBJECT(
  '_id', o.order_id,
  'status', o.order_status,
  'purchased_at', IF(o.order_purchase_timestamp IS NULL, NULL, JSON_OBJECT('$date', DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-%dT%H:%i:%s.000Z'))),
  'approved_at', IF(o.order_approved_at IS NULL, NULL, JSON_OBJECT('$date', DATE_FORMAT(o.order_approved_at, '%Y-%m-%dT%H:%i:%s.000Z'))),
  'carrier_at', IF(o.order_delivered_carrier_date IS NULL, NULL, JSON_OBJECT('$date', DATE_FORMAT(o.order_delivered_carrier_date, '%Y-%m-%dT%H:%i:%s.000Z'))),
  'delivered_at', IF(o.order_delivered_customer_date IS NULL, NULL, JSON_OBJECT('$date', DATE_FORMAT(o.order_delivered_customer_date, '%Y-%m-%dT%H:%i:%s.000Z'))),
  'estimated_delivery_at', IF(o.order_estimated_delivery_date IS NULL, NULL, JSON_OBJECT('$date', DATE_FORMAT(o.order_estimated_delivery_date, '%Y-%m-%dT%H:%i:%s.000Z'))),
  'customer', JSON_OBJECT('customer_id', c.customer_id,
                          'unique_id',   c.customer_unique_id,
                          'zip_prefix',  c.customer_zip_code_prefix,
                          'city',        c.customer_city,
                          'state',       c.customer_state),
  'items', IFNULL((
      SELECT JSON_ARRAYAGG(JSON_OBJECT(
               'line', i.order_item_id,
               'product_id', i.product_id,
               'seller_id', i.seller_id,
               'category', t.product_category_name_english,
               'price', i.price,
               'freight', i.freight_value))
      FROM order_items i
      JOIN products p ON p.product_id = i.product_id
      LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
      WHERE i.order_id = o.order_id), JSON_ARRAY()),
  'payments', IFNULL((
      SELECT JSON_ARRAYAGG(JSON_OBJECT(
               'sequence', pay.payment_sequential,
               'type', pay.payment_type,
               'installments', pay.payment_installments,
               'value', pay.payment_value))
      FROM order_payments pay
      WHERE pay.order_id = o.order_id), JSON_ARRAY()),
  'reviews', IFNULL((
      SELECT JSON_ARRAYAGG(JSON_OBJECT(
               'review_id', r.review_id,
               'score', r.review_score,
               'title', r.review_comment_title,
               'message', r.review_comment_message,
               'created_at', IF(r.review_creation_date IS NULL, NULL, JSON_OBJECT('$date', DATE_FORMAT(r.review_creation_date, '%Y-%m-%dT%H:%i:%s.000Z'))),
               'answered_at', IF(r.review_answer_timestamp IS NULL, NULL, JSON_OBJECT('$date', DATE_FORMAT(r.review_answer_timestamp, '%Y-%m-%dT%H:%i:%s.000Z')))))
      FROM order_reviews r
      WHERE r.order_id = o.order_id), JSON_ARRAY())
)
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
ORDER BY o.order_id
LIMIT 20000
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/nosql_orders.json'
CHARACTER SET utf8mb4
FIELDS TERMINATED BY '' ESCAPED BY ''
LINES TERMINATED BY '\n';
