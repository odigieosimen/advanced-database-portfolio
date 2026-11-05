-- =====================================================================
-- Portfolio 3, demo 1: COMMIT and ROLLBACK (one session only)
-- Safe to run as a whole with:  source <path>/01_commit_rollback.sql
-- Scenario: placing an order must insert the order, insert its item and
-- reduce stock, all together or not at all (atomicity).
-- =====================================================================
USE olist_marketplace;

-- Start from a clean state
DELETE FROM order_items WHERE order_id LIKE 'p3demo%';
DELETE FROM orders      WHERE order_id LIKE 'p3demo%';
UPDATE product_stock SET quantity = 10;

SET @p      = (SELECT MIN(product_id) FROM product_stock);
SET @cust   = (SELECT customer_id FROM customers ORDER BY customer_id LIMIT 1);
SET @seller = (SELECT seller_id FROM sellers ORDER BY seller_id LIMIT 1);

SELECT '=== 1A. Successful order: COMMIT makes all three changes permanent ===' AS step;
SELECT @@autocommit AS autocommit_on;
SELECT quantity AS stock_before FROM product_stock WHERE product_id = @p;

START TRANSACTION;
INSERT INTO orders (order_id, customer_id, order_status, order_purchase_timestamp)
VALUES ('p3demo_commit_000000000000000001', @cust, 'created', NOW());
INSERT INTO order_items (order_id, order_item_id, product_id, seller_id, price, freight_value)
VALUES ('p3demo_commit_000000000000000001', 1, @p, @seller, 99.90, 10.00);
UPDATE product_stock SET quantity = quantity - 1 WHERE product_id = @p;
SELECT 'inside the transaction, before COMMIT' AS moment,
       (SELECT COUNT(*) FROM orders WHERE order_id = 'p3demo_commit_000000000000000001') AS order_rows,
       (SELECT quantity FROM product_stock WHERE product_id = @p) AS stock;
COMMIT;

SELECT 'after COMMIT' AS moment,
       (SELECT COUNT(*) FROM orders WHERE order_id = 'p3demo_commit_000000000000000001') AS order_rows,
       (SELECT quantity FROM product_stock WHERE product_id = @p) AS stock;

SELECT '=== 1B. Customer abandons checkout: ROLLBACK undoes everything ===' AS step;
START TRANSACTION;
INSERT INTO orders (order_id, customer_id, order_status, order_purchase_timestamp)
VALUES ('p3demo_rollback_0000000000000001', @cust, 'created', NOW());
INSERT INTO order_items (order_id, order_item_id, product_id, seller_id, price, freight_value)
VALUES ('p3demo_rollback_0000000000000001', 1, @p, @seller, 99.90, 10.00);
UPDATE product_stock SET quantity = quantity - 1 WHERE product_id = @p;
SELECT 'inside the transaction, before ROLLBACK' AS moment,
       (SELECT COUNT(*) FROM orders WHERE order_id = 'p3demo_rollback_0000000000000001') AS order_rows,
       (SELECT quantity FROM product_stock WHERE product_id = @p) AS stock;
ROLLBACK;

SELECT 'after ROLLBACK' AS moment,
       (SELECT COUNT(*) FROM orders WHERE order_id = 'p3demo_rollback_0000000000000001') AS order_rows,
       (SELECT quantity FROM product_stock WHERE product_id = @p) AS stock;

SELECT '=== 1C. Automatic rollback when an error happens (stored procedure) ===' AS step;
DROP PROCEDURE IF EXISTS place_order;
DELIMITER //
CREATE PROCEDURE place_order(IN p_order_id CHAR(32), IN p_product CHAR(32), IN p_qty INT)
BEGIN
  -- Any SQL error: undo the whole transaction and report failure.
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 'ORDER FAILED - transaction rolled back' AS result;
  END;

  START TRANSACTION;
  INSERT INTO orders (order_id, customer_id, order_status, order_purchase_timestamp)
    SELECT p_order_id, customer_id, 'created', NOW()
    FROM customers ORDER BY customer_id LIMIT 1;
  INSERT INTO order_items (order_id, order_item_id, product_id, seller_id, price, freight_value)
    SELECT p_order_id, 1, p_product, seller_id, 99.90, 10.00
    FROM sellers ORDER BY seller_id LIMIT 1;
  UPDATE product_stock SET quantity = quantity - p_qty WHERE product_id = p_product;
  COMMIT;
  SELECT 'ORDER PLACED - transaction committed' AS result;
END//
DELIMITER ;

-- Buying 1 unit works (stock is 9):
CALL place_order('p3demo_proc_ok_00000000000000001', @p, 1);
SELECT 'after successful CALL' AS moment,
       (SELECT COUNT(*) FROM orders WHERE order_id = 'p3demo_proc_ok_00000000000000001') AS order_rows,
       (SELECT quantity FROM product_stock WHERE product_id = @p) AS stock;

-- Buying 50 units fails: stock would go negative, the CHECK constraint
-- rejects it, and the order and item rows inserted a moment earlier vanish.
CALL place_order('p3demo_proc_fail_000000000000001', @p, 50);
SELECT 'after failed CALL' AS moment,
       (SELECT COUNT(*) FROM orders WHERE order_id = 'p3demo_proc_fail_000000000000001') AS order_rows,
       (SELECT COUNT(*) FROM order_items WHERE order_id = 'p3demo_proc_fail_000000000000001') AS item_rows,
       (SELECT quantity FROM product_stock WHERE product_id = @p) AS stock;
