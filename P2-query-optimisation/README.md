# Portfolio 2: Query Processing and Optimisation (7 marks)

## Objective
Write SQL queries for the case study, record their execution plans, add indexes, and measure and explain the performance change. Uses the data loaded in Portfolio 1.

## Files in this folder

**Scripts and documents**
- `queries.sql`: the 8 queries
- `explain_queries.sql`: the same queries wrapped in `EXPLAIN ANALYZE`, used for the measurements
- `indexes.sql`: the 6 indexes, `ANALYZE TABLE`, and a query listing index sizes
- `drop_indexes.sql`: removes the indexes to return to the baseline
- `performance-analysis.md`: method, results, plan changes and full analysis

**Raw execution plans**
- `baseline_explain.txt`: plans before the indexes (9 runs; the baseline was run in three sessions of three runs, all appended to this file)
- `after_explain.txt`: plans after the indexes (3 runs)

**Screenshots** (all stored in this folder)
- `MySQL_Queries_in_CMD.png`: running the baseline in the MySQL command-line client
- `Evidence_Quaries.png`: running `queries.sql` in Workbench (Q6 result, 171 rows)
- `Indexes_from_geolocation.png`: `SHOW INDEX FROM geolocation` before indexing (primary key only)
- `evidence06-indexes-created.png`: indexes created and `ANALYZE TABLE` completed
- `evidence07-index-sizes.png`: storage size of each index

## The queries

| # | What it answers | What it tests |
|---|---|---|
| Q1 | Canceled orders per month in 2018 | Equality plus date range filter, grouping |
| Q2 | Top 10 cities in São Paulo state by orders | Filter, join, grouping |
| Q3 | Revenue by product category | 3-table join over all items (control: no index added) |
| Q4 | One-star reviews per month | Low-selectivity filter |
| Q5 | Average coordinates for one zip code | Point lookup in a 1M-row table |
| Q6 | Average coordinates for Rio de Janeiro sellers | Join into a 1M-row table |
| Q7 | Top 3 sellers by revenue per state | CTE and window function |
| Q8 | Customers by number of orders | Grouping on `customer_unique_id` |

## How to run

1. Complete Portfolio 1 (schema and data loaded in `olist_marketplace`).
2. Run `queries.sql` in MySQL Workbench to check all 8 queries return results.
3. **Baseline:** confirm no extra indexes exist (`SHOW INDEX FROM geolocation;` shows only the primary key). In Command Prompt:
   ```
   cd "C:\Program Files\MySQL\MySQL Server 8.0\bin"
   mysql -u root -p olist_marketplace
   ```
   then at the `mysql>` prompt (adjust the paths to your repository):
   ```
   tee C:/path/to/P2-query-optimisation/baseline_explain.txt
   source C:/path/to/P2-query-optimisation/explain_queries.sql
   source C:/path/to/P2-query-optimisation/explain_queries.sql
   source C:/path/to/P2-query-optimisation/explain_queries.sql
   notee
   ```
4. Run `indexes.sql` in Workbench.
5. **After:** repeat step 3, writing to `after_explain.txt`.
6. Extract the timings with PowerShell, from the folder holding the text files:
   ```
   Select-String -Path after_explain.txt -Pattern '^EXPLAIN: ' | ForEach-Object { $_.Line }
   ```
   The `actual time=A..B` value at the top of each plan, where B is milliseconds, gives each query's total time.
7. To return to the baseline, run `drop_indexes.sql`.

## How it was tested

| Check | Method | Result |
|---|---|---|
| Queries return results | `queries.sql` run in Workbench | All run; Q6 returns 171 sellers (`Evidence_Quaries.png`) |
| No extra indexes at baseline | `SHOW INDEX FROM geolocation` | Primary key only (`Indexes_from_geolocation.png`) |
| Baseline timing | `EXPLAIN ANALYZE`, 9 runs | Median per query (see below) |
| Indexes created | `indexes.sql` | 6 indexes created, statistics refreshed (`evidence06-indexes-created.png`) |
| After timing | `EXPLAIN ANALYZE`, 3 runs | First run and median per query |
| Index storage cost | `mysql.innodb_index_stats` | `evidence07-index-sizes.png` |

## Results summary

Times in milliseconds. "First run" is a cold start and is the fairest comparison with the baseline (see `performance-analysis.md`, section 6).

| Query | Baseline median | After, first run | After, median | Plan change |
|---|---|---|---|---|
| Q1 | 16,472 | 3.79 | 1.23 | Table scan to covering index range scan |
| Q2 | 15,849 | 4,568 | 415 | Table scan to index lookup, temporary table removed |
| Q3 (control) | 17,338 | 19,297 | 1,395 | None (see below) |
| Q4 | 12,778 | 84.6 | 22.1 | Table scan to covering index lookup |
| Q5 | 1,880 | 0.165 | 0.165 | Scan of 1M rows to lookup of 103 rows |
| Q6 | 1,089 | 565 | 150 | Hash join to indexed nested loop |
| Q7 | 11,907 | 662 | 438 | Table lookups removed by covering index |
| Q8 | 24,386 | 1,365 | 1,269 | 99,441 primary-key lookups removed |

**Key findings**
- Covering indexes gave the largest gains (Q1, Q4, Q5, Q7, Q8). Q2 gained little because its filter still matches 42% of customers.
- The control query Q3 had an identical plan before and after, and its cold-start time was unchanged (about 17 s to 19 s). But its warm runs took 1.4 s, which shows that part of the "after" speed-up in every query comes from data being cached rather than from the indexes themselves. For this reason the first-run comparison and the plan changes are the reliable evidence.
- The largest new index, `idx_geo_zip_coords`, takes 37.59 MB.

The full analysis, including the plan-by-plan comparison, the cost of the indexes and the limitations, is in [`performance-analysis.md`](performance-analysis.md).

## Design choices and challenges

**Choices**
1. **Query mix:** eight queries covering a range filter, a point lookup, joins, grouping, a CTE and a window function, so that different index types could be tested.
2. **A control query (Q3)** was included deliberately, to check that indexes are not credited with improvements they did not cause.
3. **Covering indexes:** most indexes include the extra columns a query reads so MySQL can answer from the index alone.
4. **Median of several runs** rather than a single timing, to reduce noise.
5. **Command-line client with `tee`** to capture the complete execution plan as text evidence.

**Challenges**
- **Caching distorted the comparison.** The control query Q3 became about 12 times faster with no index of its own. Looking at its first run after the change showed it was cold-start time (19.3 s) matching the baseline, so the later speed-up was caching. I therefore report both the first run and the median, and lean on plan changes as the main evidence.
- **Baseline file contains 9 runs** rather than 3, because the baseline was run in three sessions and the `tee` command appends to the file. The median of all 9 is used.
- **Absolute times are slow** on this machine, so only relative changes are meaningful.

## References
- MySQL 8.0 Reference Manual: EXPLAIN statement (EXPLAIN ANALYZE), CREATE INDEX, optimisation and indexes, covering indexes.
- Olist (2018). *Brazilian E-Commerce Public Dataset by Olist.* Kaggle. CC BY-NC-SA 4.0.
