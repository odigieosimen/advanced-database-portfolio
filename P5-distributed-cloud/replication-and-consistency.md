# Replication, Consistency and Availability (Portfolio 5)

## 1. The replica set

A MongoDB **replica set** keeps the same data on several servers. One member is the **primary** and takes all writes; the others are **secondaries** that copy every change from the primary asynchronously. If the primary fails, the remaining members hold an **election** and one secondary becomes the new primary. A majority of members must agree, so with 3 members the set tolerates the loss of 1.

**What the cluster showed** (`B_the_replica_set.png`, `C_replica_set_health.png`):

| Evidence | Value |
|---|---|
| Replica set name | `atlas-236etv-shard-0` |
| Members (`db.hello()` hosts) | **3**: `...shard-00-00`, `...shard-00-01`, `...shard-00-02` |
| Primary at the time | `...shard-00-02` (`isWritablePrimary: true`) |
| Node type | `ELECTABLE` (may become primary), provider AWS, disk state `READY` |
| Member states (`rs.status()`) | 1 PRIMARY and 2 SECONDARY, all `health: 1` |
| Replication lag | **0 seconds** for every member at that moment |

## 2. Replication demonstration

`D_replication.png` shows one script that (1) inserted a document on the primary with `w: "majority"`, (2) read the same document asking for a **secondary**, and (3) asked which server answered.

| Result | Value |
|---|---|
| Write acknowledged | `true` |
| Primary | `...shard-00-02` |
| Document found when reading from a secondary | **1** |
| Server that answered the read | `...shard-00-01` |
| Answered by the primary? | **false** |

So the document written on one server was available on a different server, which shows replication working. The write used `w: "majority"`, so by the time it was acknowledged at least one secondary already held it; a `w: 1` write could briefly be missing from a secondary, and that case was not tested.

## 3. Write concern: the price of waiting for replicas

A **write concern** says how many members must confirm a write before the client is told it succeeded. `w: 1` waits for the primary only; `w: "majority"` waits for a majority of members (2 of 3), so the write survives the loss of the primary.

Average time per insert over 30 inserts per run (`E_write_concern.png`):

| Run | Write concern | Average per insert |
|---|---|---|
| a | `w: 1` | 267.9 ms |
| a | `w: "majority"` | 183.9 ms |
| b | `w: 1` | 186.7 ms |
| b | `w: "majority"` | 185.5 ms |

**Interpretation.**
- All runs after the first sit at about **185 ms**. The first run (267.9 ms) was slower probably because the connection was still warming up; it should not be read as "`w: 1` is slow".
- In the second pair `w: 1` and `w: "majority"` differ by about 1 ms, which is within the noise between runs. **No cost of the majority guarantee could be measured in this setup.**
- The reason is that the client is in Lagos and the cluster in Paris, so each insert is dominated by the network round trip. Copying to another server inside the same cloud region takes only a small fraction of that.
- The conclusion is limited to this test: on a healthy cluster, majority writes cost very little, so the stronger guarantee is a sensible default for important data such as orders. A busy or degraded cluster, or members in different regions, would show a larger gap.

## 4. Consistency and availability

| Situation | Behaviour | Consistency | Availability |
|---|---|---|---|
| Read from the primary (the default) | Always the latest committed data | Strong | Needs a primary to exist |
| Read from a secondary | May be a moment behind the primary (lag was 0 s in the test) | Eventual | Works while the secondary is up |
| Write with `w: 1` | Fast, but acknowledged data can be lost if the primary fails before replicating | Weaker | High |
| Write with `w: "majority"` | Acknowledged data survives a primary failure | Stronger | Needs a majority of members reachable |

**CAP trade-off.** If a network partition cuts the primary off from the majority, the primary steps down and the majority side elects a new one. During that short election no writes are possible. MongoDB therefore favours **consistency** over write availability. Reads from secondaries can continue in the meantime, accepting possibly stale data.

**Failover was not tested.** Triggering a failover needs a paid cluster tier. The description above comes from the MongoDB documentation, not from an experiment.

**Failure tolerance of this cluster.** With 3 voting members, a majority is 2. Losing one member leaves a working replica set; losing two leaves a single member that cannot elect itself primary, so writes stop.

## 5. What to use where in the case study

| Operation | Read and write from | Reason |
|---|---|---|
| Placing an order, taking payment, reducing stock | Primary, `w: "majority"` | Must be correct and durable (Portfolio 3) |
| Order history page | A secondary may be used | A slightly old view is acceptable |
| The page shown **right after** placing an order | Primary | A secondary might not have the new order yet |
| Reports and dashboards | A secondary or a dedicated analytics node | Keeps heavy reads off the primary |

## 6. The relational side

The local MySQL database in Portfolios 1 to 3 is a single server, so replication was **not** run. The same ideas apply:
- MySQL replicates through its binary log from a **source** to one or more **replicas**, asynchronously by default (semi-synchronous replication waits for at least one replica).
- Automatic failover needs extra tooling or MySQL's Group Replication and InnoDB Cluster.
- **Replicas can lag.** Checking stock on a replica could show stock that has already been sold. This links to Portfolio 3: the stock check and update must happen on the primary inside the transaction (`SELECT ... FOR UPDATE` or the conditional update), and replicas should serve only reports and page views.
