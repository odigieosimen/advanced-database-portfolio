-- =====================================================================
-- Portfolio 3, demo 2: ISOLATION LEVELS (two sessions)
-- NOT a script to run with "source". Open two Command Prompt windows,
-- connect both, run session_init.sql in both, then paste the steps below
-- in the order shown, one at a time, switching windows as marked.
-- =====================================================================

-- ############ PART 1: dirty read at READ UNCOMMITTED ############
-- [A] 1
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT @@transaction_isolation;
-- [A] 2
START TRANSACTION;
SELECT quantity FROM product_stock WHERE product_id = @p;     -- note the value
-- [B] 3   (START TRANSACTION keeps this change uncommitted)
START TRANSACTION;
UPDATE product_stock SET quantity = quantity - 5 WHERE product_id = @p;
-- [A] 4
SELECT quantity FROM product_stock WHERE product_id = @p;     -- DIRTY READ: sees B's uncommitted change
-- [B] 5
ROLLBACK;
-- [A] 6
SELECT quantity FROM product_stock WHERE product_id = @p;     -- back to the original: A read data that never existed
COMMIT;

-- ############ PART 2: non-repeatable read at READ COMMITTED ############
-- [A] 1
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
SELECT quantity FROM product_stock WHERE product_id = @p;     -- note the value
-- [B] 2   (autocommit is on: this commits immediately)
UPDATE product_stock SET quantity = quantity - 1 WHERE product_id = @p;
-- [A] 3
SELECT quantity FROM product_stock WHERE product_id = @p;     -- NON-REPEATABLE READ: same query, different answer
COMMIT;

-- ############ PART 3: REPEATABLE READ (InnoDB's default) ############
-- [A] 1
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT quantity FROM product_stock WHERE product_id = @p;     -- note the value
-- [B] 2
UPDATE product_stock SET quantity = quantity - 1 WHERE product_id = @p;
-- [A] 3
SELECT quantity FROM product_stock WHERE product_id = @p;     -- SAME value as step 1: A keeps its snapshot
-- [A] 4   (a locking read ignores the snapshot and sees the latest committed value)
SELECT quantity FROM product_stock WHERE product_id = @p FOR UPDATE;
-- [A] 5
COMMIT;
SELECT quantity FROM product_stock WHERE product_id = @p;     -- after COMMIT A sees the latest value
