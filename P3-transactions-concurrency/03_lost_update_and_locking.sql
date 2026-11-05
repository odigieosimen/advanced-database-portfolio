-- =====================================================================
-- Portfolio 3, demo 3: LOST UPDATE and how to prevent it (two sessions)
-- NOT a script to run with "source". Use two windows as in demo 2.
-- Scenario: two customers buy the same product at the same moment.
-- Both sessions stay at the default REPEATABLE READ level.
-- =====================================================================

-- ############ PART 1: the problem (no locking) ############
-- [either] reset: stock = 10
UPDATE product_stock SET quantity = 10 WHERE product_id = @p;
-- [A] 1   (the application reads the stock, then writes back its own calculation)
START TRANSACTION;
SELECT quantity INTO @q FROM product_stock WHERE product_id = @p;
SELECT @q;                                                    -- 10
-- [B] 2
START TRANSACTION;
SELECT quantity INTO @q FROM product_stock WHERE product_id = @p;
SELECT @q;                                                    -- also 10
-- [A] 3
UPDATE product_stock SET quantity = @q - 1 WHERE product_id = @p;
COMMIT;                                                       -- stock = 9
-- [B] 4
UPDATE product_stock SET quantity = @q - 1 WHERE product_id = @p;
COMMIT;                                                       -- stock = 9 again: A's sale is overwritten
-- [either] 5
SELECT quantity FROM product_stock WHERE product_id = @p;     -- 9, but two units were sold, so it should be 8: LOST UPDATE

-- ############ PART 2: fix with SELECT ... FOR UPDATE ############
-- [either] reset
UPDATE product_stock SET quantity = 10 WHERE product_id = @p;
-- [A] 1   (this read locks the row)
START TRANSACTION;
SELECT quantity INTO @q FROM product_stock WHERE product_id = @p FOR UPDATE;
SELECT @q;                                                    -- 10
-- [B] 2   (the timeout setting gives you 5 minutes instead of 50 seconds)
SET SESSION innodb_lock_wait_timeout = 300;
START TRANSACTION;
SELECT quantity INTO @q FROM product_stock WHERE product_id = @p FOR UPDATE;
-- B now WAITS: no prompt comes back. Take a screenshot of the hanging window.
-- [A] 3
UPDATE product_stock SET quantity = @q - 1 WHERE product_id = @p;
COMMIT;                                                       -- releases the lock; B's command now completes
-- [B] 4
SELECT @q;                                                    -- 9: B sees A's committed change
UPDATE product_stock SET quantity = @q - 1 WHERE product_id = @p;
COMMIT;
-- [either] 5
SELECT quantity FROM product_stock WHERE product_id = @p;     -- 8: both sales counted

-- ############ PART 3: the last item, with an atomic conditional update ############
-- [either] reset: only 1 unit left
UPDATE product_stock SET quantity = 1 WHERE product_id = @p;
-- [A] 1
START TRANSACTION;
UPDATE product_stock SET quantity = quantity - 1 WHERE product_id = @p AND quantity >= 1;
SELECT ROW_COUNT() AS rows_updated;                           -- 1: A got the last item
-- [B] 2
SET SESSION innodb_lock_wait_timeout = 300;
START TRANSACTION;
UPDATE product_stock SET quantity = quantity - 1 WHERE product_id = @p AND quantity >= 1;
-- B WAITS for A. Screenshot the hanging window.
-- [A] 3
COMMIT;
-- [B] 4
SELECT ROW_COUNT() AS rows_updated;                           -- 0: sold out, B correctly gets nothing
ROLLBACK;
-- [either] 5
SELECT quantity FROM product_stock WHERE product_id = @p;     -- 0, never negative, never oversold
