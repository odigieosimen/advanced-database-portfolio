# Normalisation (Portfolio 1)

This document explains how the schema in `schema.sql` reaches third normal form (3NF), using the Olist marketplace as the case study. It starts from a single flat table, shows what goes wrong with it, and decomposes it step by step into the tables actually built. It also states where the design deliberately stops short of full 3NF and why.

## 1. Starting point: one flat table

Imagine all the data kept in one spreadsheet-style table, one row for every combination of order, item and payment:

`sales_flat(order_id, order_item_id, payment_sequential, order_status, order_purchase_timestamp, customer_id, customer_city, customer_state, product_id, product_category_name, product_category_name_english, seller_id, seller_city, seller_state, price, freight_value, payment_type, payment_installments, payment_value)`

The key of this table is `(order_id, order_item_id, payment_sequential)`.

### Problems with the flat table (anomalies)

| Anomaly | What happens |
|---|---|
| **Update** | A seller moves city. Their city is stored on every row they appear in, so every row must change. If one is missed, the same seller has two different cities. |
| **Insertion** | A new seller or product cannot be stored until it appears in an order, because every row needs an `order_id`. |
| **Deletion** | Deleting the only order that contains a product also deletes everything known about that product. |
| **Wrong totals** | An order with 2 items and 2 payments produces 4 rows, so each payment is counted twice. See the example below. |

**Worked example of the wrong-totals problem.** One order has two items (price 50 and 30, total 80) and two payments (60 and 20, total 80). In the flat table:

| order_id | order_item_id | price | payment_sequential | payment_value |
|---|---|---|---|---|
| O1 | 1 | 50 | 1 | 60 |
| O1 | 1 | 50 | 2 | 20 |
| O1 | 2 | 30 | 1 | 60 |
| O1 | 2 | 30 | 2 | 20 |

`SUM(payment_value)` returns **160**, although the customer paid **80**. Separating items and payments into their own tables fixes this, because each fact is stored once.

## 2. First normal form (1NF)

1NF requires that every column holds a single atomic value, with no repeating groups, and that every row is uniquely identifiable.

- An order contains several items and may be paid in several parts. These must not be stored as lists inside one cell (for example `"p1;p2;p3"` or `"credit_card:60;voucher:20"`). Each item and each payment gets its own row.
- Every table has a primary key, so rows are unique.
- Timestamps, prices and codes are single values. A free-text review message is one atomic text value from the database's point of view.

The flat table above is in 1NF.

## 3. Second normal form (2NF)

2NF requires that no non-key column depends on only part of a composite key. In `sales_flat` the key has three parts, and many columns depend on only some of them:

| Depends only on | Columns | Moves to |
|---|---|---|
| `order_id` | `order_status`, `order_purchase_timestamp`, `customer_id` (and customer details) | `orders` |
| `order_id`, `order_item_id` | `product_id`, `seller_id`, `price`, `freight_value` (and product and seller details) | `order_items` |
| `order_id`, `payment_sequential` | `payment_type`, `payment_installments`, `payment_value` | `order_payments` |

After this split, each table's non-key columns depend on its whole key.

## 4. Third normal form (3NF)

3NF requires that non-key columns depend on the key and not on another non-key column (no transitive dependencies). Four transitive dependencies remain after step 3:

| Dependency | Resolved by |
|---|---|
| `product_id` determines the category and the product's physical attributes | `products` table, keyed by `product_id` |
| `product_category_name` determines the English name | `category_translation`, keyed by `product_category_name` |
| `seller_id` determines the seller's city and state | `sellers` table, keyed by `seller_id` |
| `customer_id` determines the customer's details | `customers` table, keyed by `customer_id` |

Foreign keys then link the tables again, and the database enforces this: `orders` to `customers`, and `order_items` to `orders`, `products` and `sellers`; `order_payments` and `order_reviews` to `orders`.

## 5. Result: normal form of each table

| Table | Primary key | Highest normal form | Notes |
|---|---|---|---|
| `customers` | `customer_id` | 2NF (see section 6) | City and state depend on the zip prefix |
| `sellers` | `seller_id` | 2NF (see section 6) | Same reason |
| `products` | `product_id` | 3NF | Category translation is in its own table |
| `orders` | `order_id` | 3NF | Customer details live in `customers` |
| `order_items` | `order_id`, `order_item_id` | 3NF | `price` belongs to the order line, not to the product, because the same product can sell at different prices |
| `order_payments` | `order_id`, `payment_sequential` | 3NF | One row per payment part |
| `order_reviews` | `review_id`, `order_id` | 3NF | `review_id` alone repeats, so it cannot be the key |
| `category_translation` | `product_category_name` | 3NF | Lookup table |
| `geolocation` | `geolocation_id` | See section 6 | Reference data kept as supplied |

## 6. Where the design deliberately stops short of full 3NF

**Zip code to city and state in `customers` and `sellers`.** A zip prefix largely determines the city and state, which is a transitive dependency. In strict 3NF these would move to a zip-code table referenced by a foreign key. This was not done because the data does not support it: **157 customer zip prefixes have no row in `geolocation`** (see `evidence_missing_cust.png`), so the foreign key would reject real customers. Keeping city and state on the customer and seller rows is a deliberate trade-off between strict normal form and data completeness. The dependency is also only assumed, not guaranteed, since the source data can contain spelling variants of a city name.

**`category_translation` without a foreign key.** Two categories used by products, `pc_gamer` and `portateis_cozinha_e_preparadores_de_alimentos`, have no English translation (see `Evidence_product_category_name.png`). A foreign key would block those products from loading. The table stays as a lookup, joined with `LEFT JOIN` when translating.

**`geolocation`.** This is reference data kept as supplied. It holds about a million rows, with many rows for the same zip prefix and the same city and state repeated each time, so it is not normalised. A normalised version would have one row per zip prefix. It was left as supplied on purpose, because it also serves as a large table for the query optimisation work in Portfolio 2.

**`customer_id` versus `customer_unique_id`.** Olist generates a new `customer_id` for each order, so one real person can appear as several `customers` rows. `customer_unique_id` identifies the person. A stricter design would split this into a `persons` table and a per-order link. It was kept as supplied, with `customer_unique_id` used when a query needs to count real buyers.

**Review keys.** `review_id` appears more than once in the data: 99,224 rows but only 98,410 distinct `review_id` values (see `evidence_total_row.png`). The composite key `(review_id, order_id)` is therefore used, and all 99,224 rows loaded without a key conflict.

## 7. Normalisation and performance

A fully normalised design avoids anomalies but needs more joins to answer a question. Portfolio 2 measures that cost and reduces it with indexes. Portfolio 4 looks at the opposite choice, where a document database stores related data together (denormalised) to make some reads faster.
