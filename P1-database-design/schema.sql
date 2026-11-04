-- =====================================================================
-- MIT 8103 Portfolio 1: Database Design and Modelling
-- Case study: Olist-style online marketplace (MySQL 8)
-- Run this whole script in MySQL Workbench (lightning bolt button).
-- Safe to re-run: it drops and recreates the tables.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS olist_marketplace
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE olist_marketplace;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS order_reviews, order_payments, order_items, orders,
                     products, sellers, customers,
                     category_translation, geolocation;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------- Parent tables ----------

CREATE TABLE customers (
  customer_id              CHAR(32)     NOT NULL,   -- generated per order in Olist
  customer_unique_id       CHAR(32)     NOT NULL,   -- identifies the real person
  customer_zip_code_prefix CHAR(5)      NOT NULL,
  customer_city            VARCHAR(100) NOT NULL,
  customer_state           CHAR(2)      NOT NULL,
  PRIMARY KEY (customer_id)
) ENGINE=InnoDB;

CREATE TABLE sellers (
  seller_id              CHAR(32)     NOT NULL,
  seller_zip_code_prefix CHAR(5)      NOT NULL,
  seller_city            VARCHAR(100) NOT NULL,
  seller_state           CHAR(2)      NOT NULL,
  PRIMARY KEY (seller_id)
) ENGINE=InnoDB;

CREATE TABLE products (
  product_id                 CHAR(32)     NOT NULL,
  product_category_name      VARCHAR(100) NULL,
  product_name_length        INT          NULL,
  product_description_length INT          NULL,
  product_photos_qty         INT          NULL,
  product_weight_g           INT          NULL,
  product_length_cm          INT          NULL,
  product_height_cm          INT          NULL,
  product_width_cm           INT          NULL,
  PRIMARY KEY (product_id),
  CONSTRAINT chk_product_weight CHECK (product_weight_g IS NULL OR product_weight_g >= 0)
) ENGINE=InnoDB;

-- ---------- Core transaction tables ----------

CREATE TABLE orders (
  order_id                      CHAR(32)    NOT NULL,
  customer_id                   CHAR(32)    NOT NULL,
  order_status                  VARCHAR(20) NOT NULL,
  order_purchase_timestamp      DATETIME    NOT NULL,
  order_approved_at             DATETIME    NULL,
  order_delivered_carrier_date  DATETIME    NULL,
  order_delivered_customer_date DATETIME    NULL,
  order_estimated_delivery_date DATETIME    NULL,
  PRIMARY KEY (order_id),
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)
    REFERENCES customers (customer_id),
  CONSTRAINT chk_order_status CHECK (order_status IN
    ('created','approved','invoiced','processing','shipped',
     'delivered','unavailable','canceled'))
) ENGINE=InnoDB;

CREATE TABLE order_items (
  order_id            CHAR(32)      NOT NULL,
  order_item_id       INT           NOT NULL,   -- line number within the order
  product_id          CHAR(32)      NOT NULL,
  seller_id           CHAR(32)      NOT NULL,
  shipping_limit_date DATETIME      NULL,
  price               DECIMAL(10,2) NOT NULL,
  freight_value       DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (order_id, order_item_id),
  CONSTRAINT fk_items_order   FOREIGN KEY (order_id)   REFERENCES orders (order_id),
  CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products (product_id),
  CONSTRAINT fk_items_seller  FOREIGN KEY (seller_id)  REFERENCES sellers (seller_id),
  CONSTRAINT chk_item_price   CHECK (price >= 0),
  CONSTRAINT chk_item_freight CHECK (freight_value >= 0)
) ENGINE=InnoDB;

CREATE TABLE order_payments (
  order_id             CHAR(32)      NOT NULL,
  payment_sequential   INT           NOT NULL,
  payment_type         VARCHAR(20)   NOT NULL,
  payment_installments INT           NOT NULL,
  payment_value        DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (order_id, payment_sequential),
  CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders (order_id),
  CONSTRAINT chk_payment_type CHECK (payment_type IN
    ('credit_card','boleto','voucher','debit_card','not_defined')),
  CONSTRAINT chk_payment_value CHECK (payment_value >= 0),
  CONSTRAINT chk_installments  CHECK (payment_installments >= 0)
) ENGINE=InnoDB;

CREATE TABLE order_reviews (
  review_id               CHAR(32)     NOT NULL,
  order_id                CHAR(32)     NOT NULL,
  review_score            TINYINT      NOT NULL,
  review_comment_title    VARCHAR(255) NULL,
  review_comment_message  TEXT         NULL,
  review_creation_date    DATETIME     NULL,
  review_answer_timestamp DATETIME     NULL,
  PRIMARY KEY (review_id, order_id),   -- review_id alone repeats in the source data
  CONSTRAINT fk_reviews_order FOREIGN KEY (order_id) REFERENCES orders (order_id),
  CONSTRAINT chk_review_score CHECK (review_score BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- ---------- Reference / lookup tables (no FK, see README design notes) ----------

CREATE TABLE category_translation (
  product_category_name         VARCHAR(100) NOT NULL,
  product_category_name_english VARCHAR(100) NOT NULL,
  PRIMARY KEY (product_category_name)
) ENGINE=InnoDB;

CREATE TABLE geolocation (
  geolocation_id              INT           NOT NULL AUTO_INCREMENT,
  geolocation_zip_code_prefix CHAR(5)       NOT NULL,
  geolocation_lat             DECIMAL(18,15) NOT NULL,
  geolocation_lng             DECIMAL(18,15) NOT NULL,
  geolocation_city            VARCHAR(100)  NOT NULL,
  geolocation_state           CHAR(2)       NOT NULL,
  PRIMARY KEY (geolocation_id)
) ENGINE=InnoDB;

-- NOTE: no extra indexes beyond keys on purpose. P2 will measure queries
-- first, then add indexes and compare.
