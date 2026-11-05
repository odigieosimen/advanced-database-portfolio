// =====================================================================
// MIT 8103 Portfolio 5: distributed and cloud evidence on MongoDB Atlas
// Run in the MONGOSH panel of Compass. Compass prints ONLY THE LAST RESULT
// of what you paste, so paste ONE block at a time (each block below is a
// single expression) and screenshot each result.
// =====================================================================
use olist_nosql

// ---------- A. Is the data still there? (expect 20000 orders) ----------
({ orders: db.orders.countDocuments(), products: db.products.countDocuments(), sellers: db.sellers.countDocuments() })

// ---------- B. The replica set: name, members, which one is primary ----------
// Look for: setName, hosts (3 members), primary, me.
db.hello()

// ---------- C. Replica set health (may be blocked on the free tier: that is fine) ----------
(() => {
  try {
    const s = rs.status();
    const p = s.members.find(m => m.stateStr === "PRIMARY");
    return { set: s.set, members: s.members.map(m => ({
      name: m.name, state: m.stateStr, health: m.health,
      lag_seconds: p ? (p.optimeDate - m.optimeDate) / 1000 : null })) };
  } catch (e) { return "rs.status() not available here: " + e.message; }
})()

// ---------- D. Replication: write on the primary, read the SAME document from a secondary ----------
(() => {
  const id = "p5-" + Date.now();
  const w = db.p5_demo.insertOne({ _id: id, note: "replication test", at: new Date() },
                                 { writeConcern: { w: "majority" } });
  const primary = db.hello().primary;
  const found = db.p5_demo.find({ _id: id }).readPref("secondary").toArray().length;
  const served_by = db.p5_demo.find({ _id: id }).readPref("secondary")
                      .explain("queryPlanner").serverInfo.host;
  return { acknowledged: w.acknowledged, primary, read_from_secondary_found: found,
           read_served_by: served_by, served_by_is_primary: served_by === primary };
})()

// ---------- E. Write concern: the cost of waiting for the replicas ----------
// w:1 returns once the primary has the write; w:"majority" waits for a majority of members.
// Four runs of 30 inserts each, alternating, to show the noise. Takes a minute.
(() => {
  const n = 30;
  const avg = (wc) => {
    const t0 = Date.now();
    for (let i = 0; i < n; i++) db.p5_demo.insertOne({ run: String(wc.w), i }, { writeConcern: wc });
    return Math.round((Date.now() - t0) / n * 10) / 10;
  };
  return { inserts_per_run: n, avg_ms_w1_a: avg({ w: 1 }), avg_ms_majority_a: avg({ w: "majority" }),
           avg_ms_w1_b: avg({ w: 1 }), avg_ms_majority_b: avg({ w: "majority" }) };
})()

// ---------- F. Clean up the demo collection ----------
db.p5_demo.drop()

// ---------- G. Shard-key evidence: how are the orders spread? ----------
// G1. Skew by customer state (a state as shard key would pile data onto one shard)
(() => {
  const g = db.orders.aggregate([{ $group: { _id: "$customer.state", orders: { $sum: 1 } } },
                                 { $sort: { orders: -1 } }]).toArray();
  const total = g.reduce((s, x) => s + x.orders, 0);
  return { total, states: g.length,
           top3: g.slice(0, 3).map(x => ({ state: x._id, orders: x.orders,
                                           share_pct: Math.round(x.orders / total * 1000) / 10 })) };
})()
// G2. Spread by customer (a customer id has many distinct values, none dominant)
(() => {
  const g = db.orders.aggregate([{ $group: { _id: "$customer.unique_id", orders: { $sum: 1 } } },
                                 { $sort: { orders: -1 } }]).toArray();
  return { distinct_customers: g.length, most_orders_by_one_customer: g[0].orders,
           customers_with_one_order: g.filter(x => x.orders === 1).length };
})()
// G3. Time span of the orders (dates only ever grow, which matters for a date-based key)
db.orders.aggregate([{ $group: { _id: null, first: { $min: "$purchased_at" }, last: { $max: "$purchased_at" } } }])

// ---------- H. How big is the data? (does it even need sharding?) ----------
(() => {
  try {
    const s = db.orders.stats();
    const mb = (b) => Math.round(b / 1048576 * 10) / 10;
    return { documents: s.count, avg_doc_bytes: s.avgObjSize, data_mb: mb(s.size),
             storage_mb: mb(s.storageSize), indexes_mb: mb(s.totalIndexSize) };
  } catch (e) { return "stats not available: " + e.message; }
})()
