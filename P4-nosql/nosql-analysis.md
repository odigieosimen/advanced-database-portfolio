# NoSQL Analysis (Portfolio 4)

## 1. What was built

The Olist marketplace data from Portfolio 1 was re-modelled as documents and loaded into **MongoDB Atlas** (free M0 cluster), using MongoDB Compass to load files and to run queries in its built-in shell. The shell prompt in the screenshots shows the connection to the **primary** member of an Atlas replica set, which Portfolio 5 builds on.

| Collection | Documents | Content |
|---|---|---|
| `orders` | 20,000 (a sample of the 99,441 orders) | the order, a snapshot of the customer, and embedded `items`, `payments` and `reviews` arrays |
| `products` | all products | category (Portuguese and English), dimensions, photo count |
| `sellers` | all sellers | location |

Data was exported from MySQL with `export_to_json.sql` (JSON built with `JSON_OBJECT` and `JSON_ARRAYAGG`, dates written as Extended JSON so MongoDB stores real dates) and imported with Compass. After import, the order count matched the export (20,000) and `purchased_at` was stored as a date type, not text. The design reasoning (what is embedded and what is referenced) is in [`data-model.md`](data-model.md).

## 2. Results

| # | Task | Result observed |
|---|---|---|
| 1 | Read a whole order | One document returned the order with its items, its review and the customer. For order `00010242fe8c5a6d1ba2dd792cb16214`: one item (price 58.9, freight 13.29), status `delivered`, one review (score 5). The screenshot is cut off before the payments array |
| 2 | Canceled orders per month in 2018 | Monthly counts include 3 (January), 12 (February), 1 (March), 2 (April) and 1 (October). The filter matches **69** orders in total (the number returned in section 3) |
| 3 | Revenue by category, top 10 | Top category `health_beauty`: 251,087.87 from 1,924 items. Second, `watches_gifts`: 230,148.76 from 1,213 items |
| 4 | Average review score by customer state | Highest: PR 4.24 (959 reviews) and MS 4.21 (134 reviews). Lower: RO 3.95 (55), ES 3.92 (381), BA 3.91 (711), TO 3.90 (58) |
| 5 | Credit-card orders with 6 or more instalments | **3,238** orders |
| 6 | Top sellers with city (`$lookup`) | Guariba, SP: 42,505.84 from 228 items. Ibitinga, SP: 39,244.83 from 387 items |
| 7 | Index on `(status, purchased_at)` | After: `FETCH > IXSCAN`, 69 index keys and 69 documents examined, 69 returned, 0 ms |
| 8 | Atomic update of status and review | Ran and was restored: the order ended as `delivered` with an empty reviews list |
| 9 | Flexible schema | Three demo products with different attributes were inserted and then removed (`deletedCount: 3`) |
| 10 | Schema validation | An order with status `flying` was rejected with "Document failed validation" |

**Consistency check against the relational data.** In Portfolio 2, the full dataset had **334** canceled orders in 2018 (the plan of Q1 shows 334 rows). The 20,000-order sample is 20.1% of the 99,441 orders, and it contains 69 such orders, which is 20.7% of 334. That is what a roughly random sample should give, so the export and import did not lose or distort the data.

## 3. How the queries differ from SQL

- **No joins for the common case.** Revenue by category (task 3) needs only the `orders` collection, because each item carries its category name. The same question in SQL joins `order_items`, `products` and `category_translation`.
- **Arrays are queried directly.** `$elemMatch` (task 5) checks one payment for both `type` and `installments`; `$unwind` (tasks 3, 4, 6) turns an array into one row per element so it can be grouped.
- **Joins still exist when needed.** Sellers are referenced, not embedded, so `$lookup` (task 6) fetches their city. It works, but across large collections it is more costly than an embedded read, which is why only data that is always read together was embedded.
- **Aggregation pipelines** replace `GROUP BY`: stages such as `$match`, `$group`, `$sort`, `$limit` and `$project` run in order, each feeding the next.

## 4. Indexing

The same idea as Portfolio 2 applies: an index lets the database go straight to matching entries. The compound index `{ status: 1, purchased_at: 1 }` puts the equality field first and the range field second, so MongoDB can find "canceled" orders and then read only the 2018 range inside them. After creating it, the plan was `FETCH > IXSCAN` and examined **69 documents to return 69**: no wasted reads.

For comparison, in Portfolio 2 the equivalent MySQL index took the query from reading all 99,441 rows to reading 334.

**Not measured:** the plan **before** the index was not captured. The Compass shell prints only the last result of a pasted block, and the before-plan was pasted together with the index creation. Without an index on these fields MongoDB has no alternative to examining every document in the collection (20,000), so a large reduction is expected, but it is not claimed as a measured result here.

## 5. One document, one atomic write

In MySQL, changing an order's status and adding a review touches two tables, so Portfolio 3 needed a transaction to keep them consistent. In MongoDB both changes sit in one document, and a write to a single document is atomic by design: another client sees either the old document or the new one, never a half-changed one. The update was run (`$set` on the status and `$push` of a review) and then reversed (`$set` and `$pull`); the final read shows the order back as `delivered` with an empty reviews list. The intermediate state was not captured in a screenshot.

This is a benefit of the embedding choice, not a general replacement for transactions: operations spanning several documents (for example stock in one collection and an order in another) need multi-document transactions, which MongoDB supports on replica sets but at a performance cost.

## 6. Flexible schema and validation

**Flexible schema.** Three illustrative products (a laptop, a shirt and a book, not real Olist data) were stored with different attributes (RAM and CPU, sizes and material, ISBN and pages). A relational table would need many mostly empty columns or several extra tables to hold these. The documents were then deleted, and the delete reported 3 removals.

**Validation.** MongoDB has no foreign keys or CHECK constraints, but a JSON Schema validator can enforce some rules. One was set on `orders` (required fields and a fixed list of statuses, like the MySQL CHECK), at the `moderate` level so existing documents are not rechecked. The invalid order was rejected. Validation covers the shape of a single document only; it cannot check that an item's `seller_id` actually exists in `sellers`, so referential integrity becomes the application's job.

## 7. Suitability

| Fits MongoDB well | Fits the relational database better |
|---|---|
| Order history and order detail pages (read as a whole) | Stock levels and payments, where the transaction behaviour of Portfolio 3 matters |
| Product catalogues with varied attributes | Reporting that joins many entities in many directions |
| Data written once and read often | Data needing strict integrity across records |
| Workloads that must scale across many servers | Frequently changing shared facts (a change must be made in one place only) |

A realistic system could use both: MySQL as the system of record for stock and payments, and MongoDB for the order history and catalogue views served to the website. Other NoSQL types considered in `data-model.md` (key-value for carts, graph for recommendations) would add to this, not replace it.

## 8. Limitations and known issues

- **Trailing carriage return in category names.** In the results, category names appear with a trailing `\r` (for example `health_beauty\r`). The cause is in Portfolio 1: the translation file uses Windows line endings and was loaded with a different line terminator, and the stray character travelled into the export. Counts and totals are unaffected (grouping gives the same groups), but the labels are untidy and any query filtering by category name would have to include the character. The data was not corrected for the results shown here; removing the character is a simple update in both MySQL and MongoDB.
- **Sample only.** `orders` holds 20,000 of 99,441 orders, so totals are about a fifth of the full data and differ from the MySQL figures.
- **No measured before-index plan** (section 4) and no screenshot of the intermediate state of the atomic update (section 5).
- **Free-tier cluster.** M0 limits storage and some features, and timings on it are not representative of production.
- Comparisons with the relational design are qualitative apart from the sample check in section 2; no like-for-like timing test was run.
