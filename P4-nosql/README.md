# Portfolio 4: NoSQL and Advanced Data Models (7 marks)

## Objective
Re-model the case study (the Olist online marketplace) for a NoSQL database, implement it, query it, and explain where a document model is and is not suitable compared with the relational design.

## Files in this folder

**Scripts and documents**
- `data-model.md`: the document design, embed-versus-reference decisions and suitability discussion
- `export_to_json.sql`: exports products, sellers and a sample of 20,000 orders from MySQL as JSON
- `queries.js`: the MongoDB queries run in the Compass shell
- `nosql-analysis.md`: results, comparison with the relational design, limitations
- `sample-documents/`: three example documents from each collection (the full exports are not committed)

**Screenshots** (all stored in this folder)
- `Verify_import_in_Mongosh.png`: the import check commands
- `Joining_orders_in_mongosh.png`: one order document with items, review and customer
- `Cancelled_order_per_month_in_2018.png`: canceled orders per month in 2018
- `Revenue_by_product_category.png`: revenue by category
- `Average_review_store_by_state.png`: average review score by state
- `Quering_inside_arrays.png`: credit-card orders with 6 or more instalments (3,238)
- `Top_five_sellers_with_their_cities.png`: `$lookup` to the sellers collection
- `Indexing.png`: the `planSummary` helper used to read execution plans
- `Before_the_index.png`: the plan command and the index creation
- `After_the_Index.png`: the plan after the index (`FETCH > IXSCAN`, 69 documents examined)
- `One_Doc_one_Atomic_write.png`: the single-document update and its restoration
- `Flexible_Schema.png`: demo products with different attributes (3 deleted afterwards)

## Technology
- **MongoDB Atlas** (free M0 cluster), a document database run as a replica set in the cloud
- **MongoDB Compass**, the desktop app used to import data and, through its built-in shell, run queries
- MySQL (from Portfolios 1 to 3) as the source of the data

## The data model

| Collection | Documents | Content |
|---|---|---|
| `orders` | 20,000 (sample of 99,441) | order, customer snapshot, embedded `items`, `payments`, `reviews` |
| `products` | one per product | category (Portuguese and English), dimensions |
| `sellers` | one per seller | location |

Items, payments and reviews are **embedded** in the order because they are always read with it and their number is small. Products and sellers are **referenced** because thousands of orders share them. The full reasoning is in [`data-model.md`](data-model.md).

## How to run

1. Complete Portfolio 1 (data in MySQL).
2. Run `export_to_json.sql` in MySQL Workbench. It writes `nosql_products.json`, `nosql_sellers.json` and `nosql_orders.json` into MySQL's import/export folder (one JSON document per line; existing files must be deleted first).
3. In MongoDB Atlas create a free cluster, a database user, and allow your IP address under Network Access.
4. In Compass, connect with the cluster's connection string. Create the database `olist_nosql` with collections `orders`, `products` and `sellers`, and import each file with **Add Data > Import JSON** (file type JSON).
5. Open the shell panel in Compass and run the blocks in `queries.js` one at a time.

## How it was tested

| Check | Method | Result |
|---|---|---|
| Import complete | document counts | the order count matched the export (20,000) |
| Dates stored as dates | `$type: "date"` count on `purchased_at` | dates were stored as dates, not text |
| One document holds a whole order | `findOne` | items, review and customer in one document |
| Aggregations work | canceled orders per month; revenue by category; review score by state | results returned (see below) |
| Array queries | `$elemMatch` on payments | 3,238 orders |
| Join between collections | `$lookup` to `sellers` | top sellers returned with their cities |
| Index used | `explain("executionStats")` after creating the index | `FETCH > IXSCAN`, 69 documents examined, 69 returned |
| Atomic update | status and review changed in one update, then restored | order back to `delivered`, no reviews |
| Flexible schema | three products with different attributes | inserted, queried, and removed (3 deleted) |
| Schema validation | insert an order with status `flying` | rejected: "Document failed validation" |

## Results summary

| Query | Result |
|---|---|
| Canceled orders in 2018 | 69 in the sample (about 20.7% of the 334 in the full data, for a 20.1% sample) |
| Revenue by category | `health_beauty` first with 251,087.87 (1,924 items), then `watches_gifts` with 230,148.76 (1,213 items) |
| Average review score by state | highest PR 4.24 and MS 4.21 |
| Credit-card orders with 6+ instalments | 3,238 |
| Top sellers | Guariba (SP) 42,505.84 and Ibitinga (SP) 39,244.83 |
| Index on `(status, purchased_at)` | 69 documents examined for 69 returned |

The full discussion is in [`nosql-analysis.md`](nosql-analysis.md).

## Known issue
Category names in the results carry a trailing carriage return (shown as `\r`, for example `health_beauty\r`). It originates in Portfolio 1: the category translation file uses Windows line endings and was loaded with a different line terminator, and the character was carried into the export. Totals are not affected, only the labels. It was not corrected in the results shown here.

## Design choices and challenges

**Choices**
1. **Embedding versus referencing** decided per relationship (see `data-model.md`): embed what is read together and bounded, reference what is shared.
2. **A 20,000-order sample** rather than all 99,441, to keep the upload to the free cluster fast. A consistency check against the relational data supports using it (section 2 of the analysis).
3. **Dates exported as Extended JSON** (`{"$date": ...}`) so that MongoDB stores real dates and date queries work.
4. **A compound index** with the equality field first and the range field second.
5. **Schema validation at the `moderate` level**, so existing documents are not rechecked.

**Challenges**
- **Getting valid JSON out of MySQL.** `INTO OUTFILE` normally doubles backslashes, which would corrupt the JSON, so the export uses `ESCAPED BY ''`. Time stamps needed a conversion into Extended JSON, and empty arrays needed `IFNULL(..., JSON_ARRAY())`.
- **The Compass shell prints only the last result of a pasted block.** Several results (the counts, the plan before the index, the middle state of the atomic update) were therefore not displayed, so those are not claimed as observed results.
- **The `\r` in category names** was discovered while inspecting documents (see the known issue above).

## References
- MongoDB Manual: data modeling (embedding and referencing), aggregation pipeline, `$lookup`, indexes and `explain`, schema validation, single-document atomicity.
- Olist (2018). *Brazilian E-Commerce Public Dataset by Olist.* Kaggle. CC BY-NC-SA 4.0.
