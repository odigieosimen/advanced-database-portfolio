-- =====================================================================
-- MIT 8103 Portfolio 3: setup for the transaction and concurrency demos
-- The Olist data has no stock levels, so this adds one small table,
-- product_stock, for the "buying the last item" scenario.
-- Run once in Workbench or the mysql client.
-- NOTE: if you ever re-run P1's schema.sql, run DROP TABLE product_stock first
-- (it has a foreign key to products).
-- =====================================================================
USE olist_marketplace;

DROP TABLE IF EXISTS product_stock;
CREATE TABLE product_stock (
  product_id CHAR(32) NOT NULL,
  quantity   INT      NOT NULL,
  PRIMARY KEY (product_id),
  CONSTRAINT fk_stock_product FOREIGN KEY (product_id) REFERENCES products (product_id),
  CONSTRAINT chk_stock_qty    CHECK (quantity >= 0)      -- stock can never go negative
) ENGINE=InnoDB;

-- Five products with 10 units each (the first five product ids).
INSERT INTO product_stock (product_id, quantity)
SELECT product_id, 10 FROM products ORDER BY product_id LIMIT 5;

SELECT * FROM product_stock ORDER BY product_id;
