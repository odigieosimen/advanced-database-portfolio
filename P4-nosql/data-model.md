# NoSQL Data Model (Portfolio 4)

## 1. Choice of database

**Type:** document database (MongoDB), run on the free tier of **MongoDB Atlas**, with MongoDB Compass for browsing and loading data.

**Why a document database for this case study.** An online order is naturally one self-contained unit: the order, who placed it, the items, how it was paid and what the customer said about it are almost always read and changed together. A document database lets that unit live in a single record, where the relational design of Portfolio 1 spreads it across five tables.

## 2. Collections

| Collection | Documents | Content |
|---|---|---|
| `orders` | one per order (a sample of 20,000) | the order, a snapshot of the customer, and embedded `items`, `payments` and `reviews` arrays |
| `products` | one per product (32,951) | category (Portuguese and English), dimensions, photo count |
| `sellers` | one per seller (3,095) | location |

### Example order document (illustrative shape; values other than the ones taken from the P1 spot check are placeholders)

```json
{
  "_id": "00010242fe8c5a6d1ba2dd792cb16214",
  "status": "delivered",
  "purchased_at": "<date>",
  "delivered_at": "<date or null>",
  "customer": { "unique_id": "<id>", "city": "campos dos goytacazes", "state": "RJ" },
  "items": [
    { "line": 1, "product_id": "<id>", "seller_id": "<id>",
      "category": "<english category>", "price": 58.9, "freight": "<number>" }
  ],
  "payments": [
    { "sequence": 1, "type": "credit_card", "installments": "<number>", "value": "<number>" }
  ],
  "reviews": [
    { "review_id": "<id>", "score": 5, "message": "<text or null>" }
  ]
}
```

## 3. Embed or reference? The design decisions

| Data | Decision | Reason |
|---|---|---|
| Order items | **Embedded** in the order | Always read with the order; a small, bounded number per order; their lifetime is the order's lifetime |
| Payments | **Embedded** | Same reasons; an order can be paid in several parts, which becomes a short array |
| Reviews | **Embedded** | Belong to one order and are read with it |
| Customer | **Embedded as a snapshot** (id, city, state) | A "who and where" copy at purchase time answers most order queries without a join; the Olist `customer_id` is already created per order |
| Products | **Referenced** by `product_id`, with the category name copied into each item | Products have their own lifecycle and are shared by thousands of orders, so embedding would copy everything and make updates costly. Copying only the category (the "extended reference" pattern) keeps the common revenue-by-category query join-free |
| Sellers | **Referenced** by `seller_id` | Shared across many orders; looked up with `$lookup` when the city is needed |

**Why not embed everything?** MongoDB documents are limited to 16 MB and unbounded arrays are a design smell. Embedding is appropriate only where the child data is bounded and belongs to one parent. Products and sellers are the opposite: many parents, so they stay separate.

## 4. Relational design versus document design

| Question | Relational (MySQL, Portfolio 1) | Document (MongoDB) |
|---|---|---|
| Read a full order | Join 5 tables | Read one document |
| Change status and add a review together | Multi-statement transaction (Portfolio 3) | One single-document update, atomic by design |
| Enforce rules | Primary and foreign keys, CHECK constraints | Optional JSON Schema validation; no foreign keys |
| Duplicated data | Avoided by normalisation | Deliberate (category and customer copied into the order) |
| Changing a shared fact (a seller's city) | Update one row | Update the `sellers` document; any copies elsewhere would need updating too |
| Different attributes per product | Many NULL columns, or extra tables | Each document carries its own fields |
| Ad-hoc reporting across everything | Strong: SQL joins and grouping | Possible with aggregation pipelines, more awkward across collections |

## 5. When this model fits, and when it does not

**Fits well:** order history pages, an order's full detail view, product catalogues with varied attributes, event-like records written once and read often, and workloads that scale out across many servers.

**Fits poorly:** data with many relationships queried in many directions, strict cross-record integrity (money and stock are better in the relational database), and reporting that joins many collections.

A realistic system could use both: MySQL as the system of record for stock and payments (where transactions matter, as shown in Portfolio 3), and MongoDB for the order history and catalogue views read by the website.

## 6. Other NoSQL types considered

| Type | Example product | Where it would fit this case study |
|---|---|---|
| Key-value | Redis | Shopping carts, sessions, a "top sellers today" leaderboard (fast reads and writes by key) |
| Graph | Neo4j | "Customers who bought this also bought" recommendations (relationships between products and buyers) |
| Wide-column | Cassandra | Very large, write-heavy event logs such as click streams |

The document model was chosen as the main example because it matches the shape of the data most directly.
