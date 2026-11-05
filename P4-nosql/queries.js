// =====================================================================
// MIT 8103 Portfolio 4: MongoDB queries for the Olist case study
// Run in the MONGOSH panel at the bottom of MongoDB Compass (connected to
// your Atlas cluster). Paste ONE numbered block at a time and screenshot the
// result. Lines starting // are comments.
// Data loaded by export_to_json.sql: orders (20,000 sample), products, sellers.
// =====================================================================

use olist_nosql

// ---------- 0. Check the import ----------
db.orders.countDocuments()      // expect 20000
db.products.countDocuments()    // expect 32951
db.sellers.countDocuments()     // expect 3095
// Dates must be stored as real dates, not text (expect 20000):
db.orders.countDocuments({ purchased_at: { $type: "date" } })

// ---------- 1. ONE document holds a whole order ----------
// Relational equivalent: joining orders, customers, order_items, order_payments, order_reviews.
db.orders.findOne({ "reviews.0": { $exists: true } })

// ---------- 2. Canceled orders per month in 2018 (relational query Q1 of P2) ----------
db.orders.aggregate([
  { $match: { status: "canceled",
              purchased_at: { $gte: ISODate("2018-01-01"), $lt: ISODate("2019-01-01") } } },
  { $group: { _id: { $dateToString: { format: "%Y-%m", date: "$purchased_at" } },
              canceled_orders: { $sum: 1 } } },
  { $sort: { _id: 1 } }
])

// ---------- 3. Revenue by product category (relational Q3 of P2) ----------
db.orders.aggregate([
  { $unwind: "$items" },
  { $group: { _id: "$items.category",
              revenue: { $sum: "$items.price" },
              items_sold: { $sum: 1 } } },
  { $sort: { revenue: -1 } },
  { $limit: 10 }
])

// ---------- 4. Average review score by customer state ----------
db.orders.aggregate([
  { $unwind: "$reviews" },
  { $group: { _id: "$customer.state",
              avg_score: { $avg: "$reviews.score" },
              reviews: { $sum: 1 } } },
  { $sort: { avg_score: -1 } }
])

// ---------- 5. Querying inside arrays: credit-card orders paid in 6+ instalments ----------
db.orders.countDocuments({
  payments: { $elemMatch: { type: "credit_card", installments: { $gte: 6 } } }
})

// ---------- 6. A join when you need one: top 5 sellers with their city ($lookup) ----------
// Sellers are referenced by id (not embedded), so $lookup fetches them.
db.orders.aggregate([
  { $unwind: "$items" },
  { $group: { _id: "$items.seller_id",
              revenue: { $sum: "$items.price" },
              items_sold: { $sum: 1 } } },
  { $sort: { revenue: -1 } },
  { $limit: 5 },
  { $lookup: { from: "sellers", localField: "_id", foreignField: "_id", as: "seller" } },
  { $unwind: "$seller" },
  { $project: { _id: 0, seller_id: "$_id", city: "$seller.city", state: "$seller.state",
                revenue: { $round: ["$revenue", 2] }, items_sold: 1 } }
])

// ---------- 7. Indexing: the same idea as Portfolio 2 ----------
// Helper that prints the useful parts of an explain plan.
function planSummary(e) {
  const wp = e.queryPlanner.winningPlan;
  let node = wp.queryPlan || wp;
  const stages = [];
  while (node) { stages.push(node.stage); node = node.inputStage; }
  const s = e.executionStats;
  return { stages: stages.join(" > "), docsExamined: s.totalDocsExamined,
           keysExamined: s.totalKeysExamined, returned: s.nReturned,
           millis: s.executionTimeMillis };
}

// 7a. BEFORE the index (expect COLLSCAN and docsExamined = 20000)
planSummary(db.orders.find({
  status: "canceled",
  purchased_at: { $gte: ISODate("2018-01-01"), $lt: ISODate("2019-01-01") }
}).explain("executionStats"))

// 7b. Create the index (equality field first, range field second)
db.orders.createIndex({ status: 1, purchased_at: 1 })

// 7c. AFTER the index (expect IXSCAN and far fewer documents examined)
planSummary(db.orders.find({
  status: "canceled",
  purchased_at: { $gte: ISODate("2018-01-01"), $lt: ISODate("2019-01-01") }
}).explain("executionStats"))

// ---------- 8. One document = one atomic write (link to Portfolio 3) ----------
// Changing the order status AND adding a review touches two relational tables
// (a transaction in MySQL). In MongoDB it is a single-document update, which is atomic.
const demo = db.orders.findOne({ status: "delivered", "reviews.0": { $exists: false } })
demo._id
db.orders.updateOne({ _id: demo._id }, {
  $set:  { status: "canceled" },
  $push: { reviews: { review_id: "demo", score: 1, title: null,
                      message: "demo review", created_at: new Date(), answered_at: null } }
})
db.orders.findOne({ _id: demo._id }, { status: 1, reviews: 1 })
// Put it back:
db.orders.updateOne({ _id: demo._id }, {
  $set:  { status: "delivered" },
  $pull: { reviews: { review_id: "demo" } }
})
db.orders.findOne({ _id: demo._id }, { status: 1, reviews: 1 })

// ---------- 9. Flexible schema: products with different attributes ----------
// ILLUSTRATIVE documents (not Olist data) showing that each product can carry
// its own attributes, which a fixed relational table cannot do without many NULL columns.
db.products.insertMany([
  { _id: "demo-laptop-0001", _demo: true, category: { en: "computers" },
    attributes: { ram_gb: 16, cpu: "8 core", screen_in: 14 } },
  { _id: "demo-shirt-0001",  _demo: true, category: { en: "fashion_clothing" },
    attributes: { sizes: ["S", "M", "L"], colour: "blue", material: "cotton" } },
  { _id: "demo-book-0001",   _demo: true, category: { en: "books" },
    attributes: { isbn: "978-0000000000", pages: 320, authors: ["A. Author"] } }
])
db.products.find({ _demo: true })
db.products.find({ "attributes.ram_gb": { $gte: 16 } })
// Clean up the demo documents:
db.products.deleteMany({ _demo: true })

// ---------- 10. OPTIONAL: constraints in MongoDB (schema validation) ----------
// The MySQL CHECK constraints have a counterpart. Skip this block if Atlas refuses it.
db.runCommand({
  collMod: "orders",
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["status", "customer", "items"],
    properties: {
      status: { enum: ["created", "approved", "invoiced", "processing", "shipped",
                       "delivered", "unavailable", "canceled"] },
      items: { bsonType: "array" }
    } } },
  validationLevel: "moderate",
  validationAction: "error"
})
// This invalid document must be rejected ("Document failed validation"):
db.orders.insertOne({ _id: "bad-order", status: "flying", customer: {}, items: [] })
