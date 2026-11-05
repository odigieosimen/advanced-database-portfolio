# MIT 8103 Advanced Database Systems Portfolio

**Student:** Osimen Odigie  
**Student ID:** 301826111  
**Session:** 2026/2027, First Semester

## Project overview

This portfolio follows an Olist-style online marketplace through relational database design, query optimisation, transaction processing, NoSQL modelling, and cloud distribution. It uses the public Brazilian E-Commerce dataset by Olist and combines implementation, measurements, experiments, and design analysis.

The coursework portfolios P1–P5 are complete. Each project folder contains its own README, scripts or design documents, and supporting evidence.

## Case study

The system represents an online marketplace where customers place orders for products sold by sellers, make payments, receive deliveries, and leave reviews. The relational and document models support common operations such as order history, sales analysis, and product and seller lookups.

## Portfolio projects

| Portfolio | Topic | Marks | Summary |
|---|---|---:|---|
| [P1 — Database Design and Modelling](P1-database-design/README.md) | Relational design | 7 | Normalised MySQL schema, constraints, ER model, data loading, and validation for nine Olist tables. |
| [P2 — Query Processing and Optimisation](P2-query-optimisation/README.md) | SQL performance | 7 | Eight analytical queries, `EXPLAIN ANALYZE` comparisons, and six workload-driven indexes, including a control query. |
| [P3 — Transactions and Concurrency](P3-transactions-concurrency/README.md) | Transaction processing | 7 | Commit and rollback, isolation levels, lost updates, row locking, atomic stock updates, and deadlock handling. |
| [P4 — NoSQL and Advanced Data Models](P4-nosql/README.md) | Document modelling | 7 | MongoDB document design, MySQL-to-JSON export, aggregation queries, indexing, schema validation, and SQL comparison. |
| [P5 — Distributed and Cloud Database](P5-distributed-cloud/README.md) | Cloud and distribution | 6 | MongoDB Atlas replica-set observations, replication and write-concern experiments, and a data-backed sharding design. |

## Dataset and tools

- **Dataset:** [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), Kaggle, CC BY-NC-SA 4.0.
- **Relational database:** MySQL Community Server 8.0.46 and MySQL Workbench.
- **Document database:** MongoDB Atlas (free M0 cluster, MongoDB 8.0.36) and MongoDB Compass.
- **Other tools:** MySQL command-line client, MongoDB Compass shell, and GitHub.

The dataset CSVs are not committed to this repository. Follow [`data/README.md`](data/README.md) to obtain the source files. Portfolio 1 creates and loads the MySQL database; later portfolios build on that work.

## Key outcomes

- **Relational model:** nine tables loaded and checked against the source data, including approximately 99,441 orders and 1,000,163 geolocation records.
- **Query optimisation:** measured eight SQL queries before and after adding six indexes. The analysis distinguishes plan changes from cache effects and reports a control query for which no relevant index was added.
- **Concurrency:** demonstrated transaction rollback, dirty and non-repeatable reads, a lost update, its locking and atomic-update remedies, and deadlock detection.
- **Document model:** imported a 20,000-order sample alongside the complete product and seller collections. Orders embed bounded, commonly read data and reference shared products and sellers.
- **Cloud distribution:** observed replication across a three-member Atlas replica set and compared `w: 1` with majority write concern. Sharding and failover were not run on the free tier; the shard-key recommendation is a measured design proposal, not a deployed configuration.

## Reproducing the work

1. Download and extract the Olist CSVs as described in [`data/README.md`](data/README.md).
2. Follow [P1's setup and load instructions](P1-database-design/README.md) to create and populate `olist_marketplace`.
3. Use the README in each portfolio folder for its prerequisites, commands, results, and supporting evidence. P2 and P3 use MySQL; P4 and P5 use MongoDB Atlas and Compass.

## References

- Olist (2018). *Brazilian E-Commerce Public Dataset by Olist.* Kaggle. Licence: CC BY-NC-SA 4.0.
- MySQL 8.0 Reference Manual.
- MongoDB Manual and MongoDB Atlas documentation.

## AI use declaration

Complete the declaration required by the course, describing any AI tools used, how they were used, and how their output was reviewed and verified.
