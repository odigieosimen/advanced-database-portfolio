# Portfolio 5: Distributed and Cloud Database (6 marks)

## Objective

Examine cloud deployment, replication, consistency, availability, and sharding for the Olist marketplace. The replica-set observations and write-concern experiments use a live MongoDB Atlas cluster; sharding and failover are design discussions because they are unavailable on the free tier.

## Files

- [`cloud-setup.md`](cloud-setup.md): Atlas deployment, region, security settings, free-tier limits, and proposed architecture.
- [`replication-and-consistency.md`](replication-and-consistency.md): replica-set health, replication evidence, write-concern timings, consistency trade-offs, and untested failover behaviour.
- [`sharding-design.md`](sharding-design.md): data-size measurements, shard-key comparison, and the recommended hashed `customer.unique_id` key.
- [`p5_queries.js`](p5_queries.js): MongoDB shell commands used to collect the evidence.
- Screenshots in this folder document cluster setup, replica-set health, replication, write concern, and shard-key measurements.

## Deployment and results

The Olist document model from Portfolio 4 was hosted on MongoDB Atlas, AWS Paris (`eu-west-3`), on the free M0 tier running MongoDB 8.0.36. The cluster showed a three-member replica set with one primary and two secondaries. A majority-acknowledged write was subsequently found when reading from a secondary.

The write-concern experiment compared `w: 1` and `w: "majority"`. In the measured runs, both were dominated by network latency between the client in Lagos and the Paris cluster; the results did not establish a measurable majority-write penalty in this setup.

The 20,000-order sample was approximately 15.8 MB of data, with an estimated 80 MB for all 99,441 orders at the measured average document size. The analysis therefore concludes that sharding is not needed at this scale. It recommends a hashed `customer.unique_id` shard key if future growth warrants sharding, based on the observed distribution and customer order-history query pattern.

## Limitations

The free tier does not support sharding or the failover tests discussed in the analysis. The proposed whole-system architecture and shard-key choice are designs, not deployed systems. See the linked analysis documents for experimental details and caveats.
