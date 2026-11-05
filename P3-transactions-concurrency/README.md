# Portfolio 3: Transactions and Concurrency (7 marks)

## Objective
Show transactions with commit and rollback, the effect of isolation levels, a concurrency problem (lost update), and the mechanisms that control it (locking, atomic updates, deadlock handling).

## Files in this folder

**Scripts**
- `00_setup.sql`: creates the `product_stock` table (10 units for each of 5 products)
- `session_init.sql`: run in each session; sets `@p` and `@p2` (the first two products)
- `reset_demo.sql`: restores stock to 10 and removes demo orders
- `01_commit_rollback.sql`: demo 1, runs as a whole script
- `02_isolation_levels.sql`: demo 2, step-by-step guide for two sessions
- `03_lost_update_and_locking.sql`: demo 3, step-by-step guide for two sessions
- `04_deadlock.sql`: demo 4, step-by-step guide for two sessions
- `transaction-analysis.md`: results, explanations and trade-offs

**Text logs of the sessions**
- `01_commit_rollback_output.txt`
- `02_isolation_sessionA.txt`, `02_isolation_sessionB.txt`
- `03_lost_update_sessionA.txt`, `03_lost_update_sessionB.txt`
- `04_deadlock_sessionA.txt`, `04_deadlock_sessionB.txt` (the B log contains the full `SHOW ENGINE INNODB STATUS` output)

**Screenshots** (all stored in this folder)
- `Demo_1_cmd_evidence.png`: demo 1, successful and failed order
- `Unit_Sold_Windows_A.png`, `Unit_Sold_Windows_B.png`: lost update, sessions A and B
- `Hanging_Window_B.png`: B waiting on A's `FOR UPDATE` lock
- `Window_B_hangs_2.png`: B waiting on A in the last-item demo
- `Window_A_hangs.png`: A after waiting 29.12 s in the deadlock demo
- `Window_B_Rollback_error.png`: ERROR 1213 in Session B
- `Deadlock_Evidence_Windows_B.png`: end of the InnoDB status output

## Case study link
The Olist data has no stock levels, so this portfolio adds a small table, `product_stock`, linked to `products`. The scenario is customers buying the same product at the same time: an order is placed as one transaction (insert the order, insert its item, reduce stock). A `CHECK (quantity >= 0)` constraint stops stock going negative.

## How to run

1. Complete Portfolios 1 and 2 (the database `olist_marketplace` must exist with its data).
2. Run `00_setup.sql` in MySQL Workbench. If `schema.sql` from P1 is ever re-run, run `DROP TABLE product_stock;` first.
3. **Demo 1 (one window).** In Command Prompt:
   ```
   cd "C:\Program Files\MySQL\MySQL Server 8.0\bin"
   mysql -u root -p olist_marketplace
   ```
   then
   ```
   tee C:/path/to/P3-transactions-concurrency/01_commit_rollback_output.txt
   source C:/path/to/P3-transactions-concurrency/01_commit_rollback.sql
   notee
   ```
4. **Demos 2 to 4 (two windows).** Open two Command Prompt windows (Session A and Session B), connect both, and in each run `source .../session_init.sql`. Follow the numbered steps in `02_...`, `03_...` and `04_...`, pasting each statement into the window marked `[A]` or `[B]`, one at a time. Use `tee` in each window to keep a log. Run `reset_demo.sql` between demos.
5. For demos 3 and 4, run `SET SESSION innodb_lock_wait_timeout = 300;` in the session that will wait, because a waiting statement fails after 50 seconds by default.

## How it was tested

| Demo | What was checked | Expected | Observed |
|---|---|---|---|
| 1A | Successful order | Rows persist after `COMMIT` | Order exists, stock 10 to 9 |
| 1B | Voluntary `ROLLBACK` | Order and stock change vanish | Order rows 1 to 0, stock back to 9 |
| 1C | Error inside a procedure | Whole order rolled back | Order and item rows 0, stock unchanged at 8 |
| 2 | READ UNCOMMITTED | A sees B's uncommitted change | 10, **5**, 10 (dirty read) |
| 2 | READ COMMITTED | A's two reads differ | 10, then **9** (non-repeatable read) |
| 2 | REPEATABLE READ | A's two reads match | 9, then **9**; `FOR UPDATE` shows 8 |
| 3 | Lost update, no locking | Stock 8 | **9**, one sale lost (`Changed: 0`) |
| 3 | `SELECT ... FOR UPDATE` | B waits, stock 8 | B waited 82.7 s, stock **8** |
| 3 | Last item, conditional update | Only one buyer succeeds | B got 0 rows after 57.1 s, stock **0** |
| 4 | Opposite lock order | One session fails with a deadlock | B received **ERROR 1213**; A committed; products 9 and 9 |
| 4 | Same lock order | No deadlock | B waited 16.5 s; both orders succeeded, products 8 and 8 |

## Results and evidence

| Finding | Evidence |
|---|---|
| Commit, rollback and automatic rollback on error | `01_commit_rollback_output.txt`, `Demo_1_cmd_evidence.png` |
| Dirty read, non-repeatable read, repeatable read | `02_isolation_sessionA.txt`, `02_isolation_sessionB.txt` |
| Lost update (9 instead of 8) | `Unit_Sold_Windows_A.png`, `Unit_Sold_Windows_B.png`, `03_lost_update_session*.txt` |
| Blocking with `FOR UPDATE` | `Hanging_Window_B.png`, `03_lost_update_sessionB.txt` |
| Last item sold once only | `Window_B_hangs_2.png`, `03_lost_update_sessionB.txt` |
| Deadlock detected and one session rolled back | `Window_A_hangs.png`, `Window_B_Rollback_error.png` |
| InnoDB deadlock report | `Deadlock_Evidence_Windows_B.png`, `04_deadlock_sessionB.txt` |

The full explanation of each result is in [`transaction-analysis.md`](transaction-analysis.md).

## Design choices and challenges

**Choices**
1. **One small, clear scenario** (buying the last units of a product) used for every demo, so each concurrency problem is easy to see.
2. **Two real database sessions** in the `mysql` command-line client, because each window is a separate connection, which is what concurrency needs.
3. **A `CHECK` constraint on stock** so the database itself refuses invalid states.
4. **A stored procedure with an error handler** to show automatic rollback.
5. **Three prevention methods compared:** `FOR UPDATE` locking, an atomic conditional update, and consistent lock ordering for deadlocks.

**Challenges**
- **A paste mistake in the first isolation attempt.** In Session A, the file name `reset_demo.sql` was pasted on the same line as the `SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED` statement, producing a syntax error, so that session stayed at REPEATABLE READ and no dirty read appeared (A read 10 every time). It is visible in both logs. I repeated Part 1 correctly after checking the prompt for the continuation marker, and the second run shows the dirty read (10, 5, 10).
- **Lock waits longer than the default timeout.** Waiting statements took 82 s and 57 s in the demos, beyond MySQL's default 50-second lock timeout, so the session timeout was raised to 300 s.
- **Slow statements on this machine** meant each demo needed patience; I waited for the `mysql>` prompt before every step.
- **Deadlock victim not under my control.** InnoDB chose which session to roll back (Session B, transaction 3005), so the steps had to be read from the actual output.

## References
- MySQL 8.0 Reference Manual: InnoDB Transaction Model, Transaction Isolation Levels, Locking Reads, Deadlocks in InnoDB, `innodb_lock_wait_timeout`.
