-- =====================================================================
-- MIT 8103 Portfolio 1: Load the Olist CSV files into MySQL
-- BEFORE RUNNING: the 9 CSV files must be inside the folder that
-- MySQL allows for imports (secure_file_priv). If your path differs
-- from the one below, use Find & Replace on this whole script:
--   C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/
-- Use forward slashes (/) even on Windows, and keep the trailing slash.
-- Load order matters: parent tables first, then tables with foreign keys.
-- Safe to re-run: each table is emptied first.
-- =====================================================================

USE olist_marketplace;

-- NOTE: ESCAPED BY '' is deliberate. With ESCAPED BY '"', IGNORE 1 LINES
-- treated the closing quote of the header as escaping the line break, so
-- the first data row of every file was silently skipped.

DROP TABLE IF EXISTS orders_stage;  -- temporary table from debugging

-- ---------- Empty tables (child tables first) ----------
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE order_reviews;
TRUNCATE TABLE order_payments;
TRUNCATE TABLE order_items;
TRUNCATE TABLE orders;
TRUNCATE TABLE products;
TRUNCATE TABLE sellers;
TRUNCATE TABLE customers;
TRUNCATE TABLE category_translation;
TRUNCATE TABLE geolocation;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------- 1. customers ----------
-- LPAD restores any zip-code leading zeros (e.g. 1151 -> 01151).
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_customers_dataset.csv'
INTO TABLE customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(customer_id, customer_unique_id, @zip, customer_city, customer_state)
SET customer_zip_code_prefix = LPAD(@zip, 5, '0');

-- ---------- 2. sellers ----------
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_sellers_dataset.csv'
INTO TABLE sellers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(seller_id, @zip, seller_city, seller_state)
SET seller_zip_code_prefix = LPAD(@zip, 5, '0');

-- ---------- 3. products ----------
-- Empty cells become NULL. The CSV header spells "lenght"; columns are
-- loaded by position, so our corrected names (length) are fine.
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_products_dataset.csv'
INTO TABLE products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, @cat, @name_len, @desc_len, @photos, @weight, @len, @height, @width)
SET product_category_name      = NULLIF(@cat, ''),
    product_name_length        = NULLIF(@name_len, ''),
    product_description_length = NULLIF(@desc_len, ''),
    product_photos_qty         = NULLIF(@photos, ''),
    product_weight_g           = NULLIF(@weight, ''),
    product_length_cm          = NULLIF(@len, ''),
    product_height_cm          = NULLIF(@height, ''),
    product_width_cm           = NULLIF(@width, '');

-- ---------- 4. orders ----------
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_orders_dataset.csv'
INTO TABLE orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, customer_id, order_status, order_purchase_timestamp,
 @approved, @carrier, @delivered, @estimated)
SET order_approved_at             = NULLIF(@approved, ''),
    order_delivered_carrier_date  = NULLIF(@carrier, ''),
    order_delivered_customer_date = NULLIF(@delivered, ''),
    order_estimated_delivery_date = NULLIF(@estimated, '');

-- ---------- 5. order_items ----------
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_order_items_dataset.csv'
INTO TABLE order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, order_item_id, product_id, seller_id, @ship_limit, price, freight_value)
SET shipping_limit_date = NULLIF(@ship_limit, '');

-- ---------- 6. order_payments ----------
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_order_payments_dataset.csv'
INTO TABLE order_payments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, payment_sequential, payment_type, payment_installments, payment_value);

-- ---------- 7. order_reviews ----------
-- IGNORE skips rows that would break the primary key (duplicate
-- review_id + order_id pairs). Run SHOW WARNINGS afterwards to see how many.
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_order_reviews_dataset.csv'
IGNORE INTO TABLE order_reviews
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(review_id, order_id, review_score, @title, @message, @created, @answered)
SET review_comment_title    = NULLIF(@title, ''),
    review_comment_message  = NULLIF(@message, ''),
    review_creation_date    = NULLIF(@created, ''),
    review_answer_timestamp = NULLIF(@answered, '');

-- ---------- 8. category_translation ----------
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/product_category_name_translation.csv'
INTO TABLE category_translation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_category_name, product_category_name_english);

-- ---------- 9. geolocation (about 1 million rows, the slowest step) ----------
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_geolocation_dataset.csv'
INTO TABLE geolocation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@zip, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state)
SET geolocation_zip_code_prefix = LPAD(@zip, 5, '0');
