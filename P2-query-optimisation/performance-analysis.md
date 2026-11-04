# Performance Analysis (Portfolio 2)

## 1. Method

- **Environment:** MySQL 8.0.46 Community Server and MySQL Workbench on Windows, default settings, data from Portfolio 1 (about 99k orders, 112k order items, 1M geolocation rows).
- **Tool:** `EXPLAIN ANALYZE`, which runs the query and reports the real time and rows at every step of the plan. Plans were captured with the `mysql` command-line client using `tee` (see `baseline_explain.txt` and `after_explain.txt`).
- **Measure:** the total time of the top plan node (`actual time=A..B`, where B is the time in milliseconds to return the last row).
- **Baseline:** no indexes other than primary keys and the foreign key indexes MySQL creates automatically (`SHOW INDEX FROM geolocation` shows only the primary key, see `Indexes_from_geolocation.png`). The query set was run 9 times (three sessions of three runs; the file holds all 9), and the **median** is used.
- **After:** the 6 indexes in `indexes.sql` were created and `ANALYZE TABLE` was run. The query set was run 3 times. Both the **first run** and the **median of the 3 runs** are reported (reason in section 6).

## 2. The queries

| # | What it answers | What it tests |
|---|---|---|
| Q1 | Canceled orders per month in 2018 | Equality filter plus date range, then grouping |
| Q2 | Top 10 cities in São Paulo state by orders | Filter on `customers`, join to `orders`, grouping |
| Q3 | Revenue by product category (top 10) | 3-table join over every order item. **Control query**: no index was added for it |
| Q4 | One-star reviews per month | Low-selectivity filter (11.5% of rows) |
| Q5 | Average coordinates for one zip code | Point lookup in a 1M-row table |
| Q6 | Average coordinates for every seller in Rio de Janeiro state | Join into the 1M-row table |
| Q7 | Top 3 sellers by revenue in each state | CTE and `RANK()` window function |
| Q8 | How many customers placed 1, 2, 3... orders | Grouping on `customer_unique_id` |

## 3. Indexes added

| Index | Table and columns | Aimed at | Why this design |
|---|---|---|---|
| `idx_orders_status_purchase` | `orders (order_status, order_purchase_timestamp)` | Q1 | Equality column first, range column second. It also contains both columns the query reads, so no table lookup is needed |
| `idx_customers_state_city` | `customers (customer_state, customer_city)` | Q2 | Equality filter on state; city is the next column needed, so grouping follows index order |
| `idx_customers_unique` | `customers (customer_unique_id)` | Q8 | Grouping on the person's id. The primary key is stored inside every secondary index, so the join column comes free |
| `idx_reviews_score_created` | `order_reviews (review_score, review_creation_date)` | Q4 | `review_score` alone is not selective, but adding the date makes the index cover the query |
| `idx_geo_zip_coords` | `geolocation (zip_prefix, lat, lng)` | Q5, Q6 | Zip lookup, with both averaged columns included so no table access is needed |
| `idx_items_seller_price` | `order_items (seller_id, price)` | Q7 | Per-seller revenue read from the index alone |

## 4. Results

All times in milliseconds. Baseline is the median of 9 runs (range in brackets). "After, first run" is a cold start; "After, median" is the median of 3 runs.

| Query | Baseline median (range) | After, first run | After, median | Speed-up, first run vs baseline | Speed-up, median vs baseline |
|---|---|---|---|---|---|
| Q1 | 16,472 (13,390 to 17,632) | 3.79 | 1.23 | about 4,350x | about 13,400x |
| Q2 | 15,849 (10,952 to 17,657) | 4,568 | 415 | about 3.5x | about 38x |
| **Q3 (control)** | 17,338 (16,330 to 20,015) | 19,297 | 1,395 | **about 0.9x (no change)** | about 12x |
| Q4 | 12,778 (11,892 to 14,648) | 84.6 | 22.1 | about 151x | about 578x |
| Q5 | 1,880 (1,541 to 2,535) | 0.165 | 0.165 | about 11,400x | about 11,400x |
| Q6 | 1,089 (1,056 to 1,393) | 565 | 150 | about 1.9x | about 7x |
| Q7 | 11,907 (11,286 to 18,254) | 662 | 438 | about 18x | about 27x |
| Q8 | 24,386 (20,885 to 29,818) | 1,365 | 1,269 | about 18x | about 19x |

The first-run column is the fairer comparison, and section 6 explains why.

## 5. What changed in each plan

| Query | Before | After | Rows read before to after |
|---|---|---|---|
| Q1 | `Table scan on orders` | `Covering index range scan on orders using idx_orders_status_purchase` | 99,441 to 334 |
| Q2 | `Table scan on c` (customers) | `Covering index lookup on c using idx_customers_state_city`; grouping streamed in index order, no temporary table | 99,441 to 41,746 |
| Q3 | Table scan on products, then lookups | Same plan | unchanged |
| Q4 | `Table scan on order_reviews` | `Covering index lookup using idx_reviews_score_created` | 99,224 to 11,424 |
| Q5 | `Table scan on geolocation` | `Covering index lookup using idx_geo_zip_coords` | 1,000,000 to 103 |
| Q6 | `Inner hash join` with a full scan of `geolocation` | `Nested loop` with a covering index lookup into `geolocation` for each of 171 sellers | 1,000,000 to 35,643 |
| Q7 | `Index lookup on i using fk_items_seller` (extra table lookup per row for `price`) | `Covering index lookup on i using idx_items_seller_price` | 112,650 rows, no table lookups |
| Q8 | Scan of `orders` index, then a primary-key lookup in `customers` for each of 99,441 rows | `Covering index scan on c using idx_customers_unique`, then a covering lookup in `orders`; the inner grouping streams without a temporary table | 99,441 lookups removed |

## 6. The control query and what it revealed

Q3 was meant to show that an index does not always help: it aggregates every order item, so no index was added for it. Its plan is the same before and after. But its median time fell from about 17.3 s to 1.4 s, a 12x change with no relevant index.

The pattern in the data explains it:
- Q3's **first** run after the indexes took 19.3 s, within the baseline range (16.3 to 20.0 s). Cold against cold, there is no improvement, as expected.
- Its next two runs took 1.4 s. Only the cache state changed, because the plan is identical.
- In the baseline, even repeated runs stayed slow (every run of Q3 took over 16 s), so the baseline queries were effectively never served from memory. The optimizer's own cost estimates changed too (for example the cost of the join step on `products` dropped from 39,706 to 14,846), which is consistent with pages now being in memory.

Likely explanation (not tested): the baseline queries scan large tables, notably the 1M-row `geolocation` table (63.6 MB for its primary key alone), and the combined working set is bigger than MySQL's default 128 MB buffer pool. Each scan pushes other tables' pages out of memory. Once the new indexes let the queries read small covering indexes instead of whole tables, everything fits in memory and even Q3 runs warm. This can be confirmed by checking `innodb_buffer_pool_size`.

**Consequences for interpreting the results:**
1. The **plan evidence** (table scan to index lookup, rows read) is reliable and unaffected by caching.
2. The **first-run comparison** is the fairest timing comparison, because both sides were reading from cold storage.
3. The "median" speed-ups mix an indexing effect with a caching effect and should not be quoted as pure index gains. Q3 shows how large the caching effect alone can be (about 12x here).
4. A side benefit of good indexes is a smaller memory footprint: they reduced the pressure on the cache for all queries, including one they were not built for.

## 7. Analysis by query

- **Q1 (largest plan change among the filter queries).** The composite index lets MySQL jump to `canceled` orders in 2018 and read only 334 index entries instead of 99,441 rows. Both columns the query uses are in the index, so the table is never touched. The temporary table remains because the grouping uses `DATE_FORMAT()`, an expression the index cannot provide.
- **Q2 (smallest gain among the filter queries).** The index removes the full scan of `customers` and the temporary table, but the query still has to find 41,746 São Paulo customers' orders, one lookup each, so most of the work remains (4.6 s on the first run, 0.4 s warm). An index helps when it cuts the number of rows that must be processed, and here the filter matches 42% of customers.
- **Q3 (control).** No change, see section 6.
- **Q4.** A filter matching 11.5% of rows is normally too unselective for an index, and `review_score` alone would not have helped. Adding `review_creation_date` made the index cover the query. It is also much narrower than the table rows, which carry large review text, so reading 11,424 index entries is far cheaper than scanning 99,224 full rows. This is why the covering design worked where a single-column index would not.
- **Q5.** The clearest case: a full scan of one million rows to find 103 becomes a direct lookup, 1.9 s to 0.17 ms.
- **Q6.** Smaller gain. Even without an index MySQL 8 used a **hash join**, which scans `geolocation` once instead of once per seller, so the baseline was already decent (about 1.1 s). The index turns it into 171 targeted lookups. The remaining time is mostly the scan of the small `sellers` table, because no index on `seller_state` was added; at 3,095 rows it is not worth one.
- **Q7.** The old plan found each seller's items through the foreign key index but then had to fetch `price` from the full row each time. The covering index holds `price`, so those lookups vanish. The rest of the time goes on the temporary tables and the window function, which an index does not remove.
- **Q8.** The old plan did 99,441 individual primary-key lookups into `customers`. With `customer_unique_id` indexed, MySQL reads the customers in order and groups them as it goes.

## 8. Cost of the indexes

- **Storage:** `idx_geo_zip_coords` takes **37.59 MB**, about 59% of the size of the `geolocation` primary key (63.58 MB). The other five new indexes are each smaller than the 10.58 MB shown in the lowest visible row of the size listing (`evidence07-index-sizes.png`).
- **Write cost:** every index must be updated on each INSERT, DELETE or UPDATE of its columns. This matters most for `idx_orders_status_purchase`: an order's status changes several times in its life (created, approved, shipped, delivered), and each change updates that index. In a busy order-processing system this overhead would need weighing against the reporting benefit. For this read-heavy analytical workload the trade is favourable.
- **Indexes not added:** `sellers (seller_state)` and `payments (payment_type)`, because the tables are small or the columns are unselective, so the gain would not justify the cost.

## 9. Conclusions

1. Indexes that match the query's filter, join and grouping columns turned full table scans into index lookups. The biggest changes came where a query needed a few rows out of a large table (Q1, Q4, Q5).
2. **Covering indexes** (Q1, Q4, Q5, Q7, Q8) were the most effective technique here, because they avoid fetching table rows altogether. Column order matters: equality columns first, then range columns.
3. Indexes do not help every query. Q2 improved modestly because the filter still matches many rows, and Q3, which touches all the data, did not improve at all.
4. **Measure carefully.** Q3 exposed a caching effect that would have inflated the apparent gains. Comparing plans and cold runs avoids drawing the wrong conclusion.
5. Indexes cost storage and write time, so each should be justified by a query that needs it.

## 10. Limitations

- Absolute times are specific to this machine and are slow (a scan of a 99k-row table took over 10 s), so only the relative changes mean anything.
- The after measurement has only 3 runs, and the buffer-pool explanation in section 6 has not been verified.
- Each query was run as part of a batch of 8, so queries influenced one another's cache state. Running each query in isolation would separate the effects more cleanly.

## 11. How to read an `EXPLAIN ANALYZE` plan

- `Table scan on X`: every row of table X is read. `Index lookup` or `Covering index lookup`: only matching entries are read through an index. `Covering` means the index alone has every column needed.
- `actual time=A..B`: milliseconds until the first row (A) and until all rows (B) are produced. `rows=N`: rows produced. `loops=N`: how many times that step ran.
- Plans are read from the innermost (most indented) step outwards.
