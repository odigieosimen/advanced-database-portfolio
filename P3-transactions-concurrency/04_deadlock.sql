-- =====================================================================
-- Portfolio 3, demo 4: DEADLOCK and how to avoid it (two sessions)
-- NOT a script to run with "source". Use two windows as before.
-- Scenario: two orders each buy products 1 and 2, but lock them in the
-- opposite order, so each waits for the other forever.
-- Work quickly through steps 3 and 4 (the default lock wait is 50 seconds).
-- =====================================================================

-- [either] reset
UPDATE product_stock SET quantity = 10;

-- ############ PART 1: causing a deadlock ############
-- [A] 1
START TRANSACTION;
UPDATE product_stock SET quantity = quantity - 1 WHERE product_id = @p;    -- A locks product 1
-- [B] 2
START TRANSACTION;
UPDATE product_stock SET quantity = quantity - 1 WHERE product_id = @p2;   -- B locks product 2
-- [A] 3
UPDATE product_stock SET quantity = quantity - 1 WHERE product_id = @p2;   -- A WAITS for B
-- [B] 4   (within 50 seconds)
UPDATE product_stock SET quantity = quantity - 1 WHERE product_id = @p;    -- B waits for A: DEADLOCK
-- InnoDB detects the cycle at once and rolls one session back with:
--   ERROR 1213 (40001): Deadlock found when trying to get lock; try restarting transaction
-- It is usually B, but if it is A, swap the roles in the rest of this part.
-- The surviving session's waiting statement now completes.
-- [A] 5   (the survivor)
COMMIT;
-- [either] 6   (the victim's changes were undone; the survivor's were kept)
SELECT product_id, quantity FROM product_stock ORDER BY product_id LIMIT 3;
-- [either] 7   (evidence: InnoDB records the deadlock, look for "LATEST DETECTED DEADLOCK")
SHOW ENGINE INNODB STATUS\G

-- ############ PART 2: preventing it with a consistent lock order ############
-- [either] reset
UPDATE product_stock SET quantity = 10;
-- Rule: always touch products in the same order (here: @p before @p2).
-- [A] 1
START TRANSACTION;
UPDATE product_stock SET quantity = quantity - 1 WHERE product_id = @p;
-- [B] 2
SET SESSION innodb_lock_wait_timeout = 300;
START TRANSACTION;
UPDATE product_stock SET quantity = quantity - 1 WHERE product_id = @p;    -- B WAITS (no deadlock possible)
-- [A] 3
UPDATE product_stock SET quantity = quantity - 1 WHERE product_id = @p2;
COMMIT;                                                                    -- B's statement now completes
-- [B] 4
UPDATE product_stock SET quantity = quantity - 1 WHERE product_id = @p2;
COMMIT;
-- [either] 5
SELECT product_id, quantity FROM product_stock ORDER BY product_id LIMIT 2;  -- both products 8: both orders succeeded
