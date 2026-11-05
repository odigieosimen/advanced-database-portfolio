# Transactions and Concurrency Analysis (Portfolio 3)

## 1. Scenario and set-up

The Olist data has no stock levels, so one small table was added for this portfolio:

`product_stock (product_id PK, quantity INT NOT NULL, CHECK (quantity >= 0))`, with a foreign key to `products`. Five products were given 10 units each (`00_setup.sql`).

The scenario is an online shop: placing an order inserts the order, inserts its item and reduces stock, and several customers may buy at once. Everything ran on MySQL 8.0.46 with the InnoDB engine. Concurrency was produced with **two `mysql` command-line windows** (Session A and Session B) each holding its own connection. A scripted single-session demo covers commit and rollback, and two windows are used for isolation, locking and deadlock. Output was recorded with `tee` into text logs and with screenshots.

## 2. Demo 1: atomicity with COMMIT and ROLLBACK

An order is three changes (order row, item row, stock reduction) that must all succeed or all fail.

| Case | Inside the transaction | After the transaction |
|---|---|---|
| 1A, `COMMIT` | order rows 1, stock 9 | order rows 1, stock 9 (permanent) |
| 1B, `ROLLBACK` (customer abandons checkout) | order rows 1, stock 8 | order rows **0**, stock **9** (everything undone) |
| 1C, procedure `place_order`, 1 unit | not shown | "ORDER PLACED", order rows 1, stock 8 |
| 1C, procedure `place_order`, 50 units | stock would go negative | "ORDER FAILED - transaction rolled back", order rows **0**, item rows **0**, stock 8 |

In case 1C the third statement (the stock update) violates the `CHECK (quantity >= 0)` constraint. The error handler in the procedure issues `ROLLBACK`, which also removes the order and item rows inserted a moment earlier. The database never holds a half-finished order. This demonstrates **atomicity** and, through the CHECK constraint, **consistency**: the invalid state (negative stock) cannot be committed.

**Durability** (committed data surviving a crash) was not tested. It is provided by InnoDB's redo log.

## 3. Demo 2: isolation levels

Session A read the stock inside a transaction while Session B changed it. The results from `02_isolation_sessionA.txt`:

| Isolation level | A's reads | B's action | Anomaly shown |
|---|---|---|---|
| READ UNCOMMITTED | 10, then **5**, then 10 | subtracted 5, did **not** commit, then rolled back | **Dirty read**: A saw a value that never became real |
| READ COMMITTED | 10, then **9** | subtracted 1 and committed | **Non-repeatable read**: same query, different answer inside one transaction |
| REPEATABLE READ | 9, then **9**; with `FOR UPDATE`: **8** | subtracted 1 and committed | None for ordinary reads. A keeps its snapshot; a locking read sees the latest committed value |

**How InnoDB achieves this.** InnoDB keeps older versions of changed rows (multi-version concurrency control). At REPEATABLE READ a transaction takes a snapshot at its first read and keeps using it, so B's commit stays invisible to A. At READ COMMITTED every statement takes a fresh snapshot, so A sees B's commit. At READ UNCOMMITTED reads ignore versions and see the newest data, even uncommitted. A locking read (`FOR UPDATE`) always reads the latest committed row, which is why A saw 8 inside the same transaction.

| Anomaly | READ UNCOMMITTED | READ COMMITTED | REPEATABLE READ | SERIALIZABLE |
|---|---|---|---|---|
| Dirty read | possible | prevented | prevented | prevented |
| Non-repeatable read | possible | possible | prevented | prevented |
| Phantom read | possible | possible | mostly prevented in InnoDB | prevented |

Phantom reads and SERIALIZABLE were not demonstrated; that row of the table is from the MySQL documentation, not from these runs.

## 4. Demo 3: lost update and how to prevent it

Two customers each buy one unit while stock is 10. The correct final stock is 8.

| Part | Method | What happened | Final stock |
|---|---|---|---|
| 1 | No locking: each session reads the stock, then writes back `@q - 1` | Both read 10. A wrote 9 and committed. B then wrote 9. MySQL reported **`Rows matched: 1  Changed: 0`** for B, because B wrote the value already there | **9** (wrong, one sale lost) |
| 2 | `SELECT ... FOR UPDATE` | A locked the row. B's own `FOR UPDATE` **waited 1 min 22.74 s**, then read **9** and wrote 8 | **8** (correct) |
| 3 | Atomic conditional update, with only **1 unit left** | `UPDATE ... SET quantity = quantity - 1 WHERE ... AND quantity >= 1`. A got `rows_updated = 1`. B **waited 57.13 s**, then got `Rows matched: 0` and rolled back | **0** (never negative, never oversold) |

**Why the lost update happens.** Both sessions made a decision from a value they read before the other committed. B's plain read came from its snapshot (10), and its write then applied to the row's newest version. No error was raised; one sale disappeared silently.

**Why the fixes work.**
- `FOR UPDATE` takes an exclusive row lock when reading, so the second session must wait and then reads the up-to-date value. This is *pessimistic* locking.
- The conditional update does the check and the change in one atomic statement, so there is no gap between "is there stock?" and "take it". The caller learns the outcome from the number of rows changed. For the last-item case it is the simplest fix, because it needs no separate read.
- A relative update (`quantity = quantity - 1` with no stale value from an earlier read) would also have avoided the lost update, though it would not stop stock going below zero without the CHECK. Optimistic locking with a version column is another approach. Neither was run.

**About the waits.** The waits of 82 s and 57 s are long because the window holding the lock sat idle while screenshots were taken. Real lock waits are usually milliseconds. They do show the cost of locking: the waiting session does nothing until the lock is released. MySQL's default `innodb_lock_wait_timeout` is 50 seconds, after which a waiting statement fails with error 1205, so the timeout was raised to 300 s for these demos.

## 5. Demo 4: deadlock

An order buys products 1 and 2. Session A touched product 1 then product 2. Session B touched product 2 then product 1.

| Step | Session A | Session B |
|---|---|---|
| 1 | updates product 1 (locks it) | |
| 2 | | updates product 2 (locks it) |
| 3 | updates product 2: **waits for B** (29.12 s) | |
| 4 | | updates product 1: **ERROR 1213** |

Each session was waiting for a lock the other held, so neither could proceed. InnoDB detected the cycle immediately and rolled back one transaction, with the message `ERROR 1213 (40001): Deadlock found when trying to get lock; try restarting transaction`. Session A's waiting statement then completed and its `COMMIT` succeeded. Final stock: products 1 and 2 at 9, which are A's two changes. B's change was undone.

`SHOW ENGINE INNODB STATUS` recorded the event under "LATEST DETECTED DEADLOCK":
- Transaction (1) was Session A (thread 25): it held the lock on product 1 and was waiting for product 2.
- Transaction (2) was Session B (thread 27): it held the lock on product 2 and was waiting for product 1.
- Both locks were exclusive record locks on the primary key of `product_stock`.
- The report ends with "WE ROLL BACK TRANSACTION (2)", so B was the victim. Both had changed one row, and InnoDB chose B.

**Prevention.** When both sessions touched the products in the **same order** (product 1 first), B simply waited **16.54 s** for A to finish, with no deadlock. Both orders then succeeded and both products ended at 8.

**Lessons.**
1. A deadlock is not a malfunction; it is an expected possibility when transactions lock several rows. The database resolves it automatically by sacrificing one transaction.
2. The application should catch error 1213 and **retry** the transaction.
3. Prevention: lock rows in a consistent order (for a multi-item order, sort by product id), keep transactions short, and avoid holding locks while waiting for a user.

## 6. Trade-offs

| Choice | Benefit | Cost |
|---|---|---|
| Lower isolation (READ COMMITTED, READ UNCOMMITTED) | Fewer waits, more throughput | Anomalies (non-repeatable and dirty reads) |
| Higher isolation, row locks (`FOR UPDATE`) | Correct results under contention | Other sessions wait; deadlocks possible |
| Atomic conditional update | Correct, no separate read, shortest lock time | Only works when the rule can be written in one statement |
| Retrying after a deadlock | Hides the failure from the customer | Extra work, and the code must be safe to repeat |

For the case study, a robust order flow would be: one transaction, atomic conditional stock updates in sorted product order, `COMMIT` on success, `ROLLBACK` on any failure, and a retry on error 1213.

## 7. Limitations

- Concurrency was produced by hand by interleaving two windows, so timings (such as the waits) reflect human pauses and a slow machine, not real load.
- Durability, SERIALIZABLE, phantom reads and optimistic locking were not demonstrated.
- The first attempt at the dirty read ran at the default isolation level because the `SET` statement was lost to a typing error (see the README). That attempt happens to show that at the default level A read 10 each time, but the correct run is the evidence for the dirty read.
- `product_stock` and the `place_order` procedure were added for this portfolio and are not part of the Olist data.
