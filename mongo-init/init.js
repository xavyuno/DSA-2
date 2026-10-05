// Runs automatically the first time the MongoDB container starts.
// Design: ONE DATABASE PER SERVICE (each microservice owns its data).
// Validators use validationAction "warn" so a type mismatch is logged, never blocks a teammate's insert.

function makeCollection(database, name, required, properties) {
  database.createCollection(name, {
    validator: { $jsonSchema: { bsonType: "object", required: required, properties: properties } },
    validationLevel: "moderate",
    validationAction: "warn"
  });
}

// ---------------- customer_db ----------------
const customerDb = db.getSiblingDB("customer_db");
makeCollection(customerDb, "customers", ["customerId", "name", "email"], {
  customerId: { bsonType: "string" },
  name: { bsonType: "string" },
  email: { bsonType: "string" },
  phone: { bsonType: "string" },
  addresses: { bsonType: "array" }
});
customerDb.customers.createIndex({ customerId: 1 }, { unique: true });
customerDb.customers.createIndex({ email: 1 }, { unique: true });

// ---------------- restaurant_db ----------------
const restaurantDb = db.getSiblingDB("restaurant_db");
makeCollection(restaurantDb, "restaurants", ["restaurantId", "name"], {
  restaurantId: { bsonType: "string" },
  name: { bsonType: "string" },
  cuisine: { bsonType: "string" },
  openingHours: { bsonType: "array" },
  isOpen: { bsonType: "bool" }
});
restaurantDb.restaurants.createIndex({ restaurantId: 1 }, { unique: true });
makeCollection(restaurantDb, "menu_items", ["itemId", "restaurantId", "name", "price"], {
  itemId: { bsonType: "string" },
  restaurantId: { bsonType: "string" },
  name: { bsonType: "string" },
  stock: { bsonType: ["int", "long", "double", "decimal"] },
  available: { bsonType: "bool" }
});
restaurantDb.menu_items.createIndex({ itemId: 1 }, { unique: true });
restaurantDb.menu_items.createIndex({ restaurantId: 1, available: 1 });

// ---------------- order_db ----------------
const orderDb = db.getSiblingDB("order_db");
makeCollection(orderDb, "orders", ["orderId", "customerId", "restaurantId", "items", "totalAmount", "status"], {
  orderId: { bsonType: "string" },
  customerId: { bsonType: "string" },
  restaurantId: { bsonType: "string" },
  items: { bsonType: "array" },
  status: { enum: ["CREATED", "CONFIRMED", "PREPARING", "READY", "OUT_FOR_DELIVERY", "DELIVERED", "CANCELLED"] }
});
orderDb.orders.createIndex({ orderId: 1 }, { unique: true });
orderDb.orders.createIndex({ customerId: 1, createdAt: -1 });
orderDb.orders.createIndex({ restaurantId: 1, status: 1 });
makeCollection(orderDb, "order_events", ["orderId", "toStatus", "timestamp"], {
  orderId: { bsonType: "string" },
  toStatus: { bsonType: "string" },
  timestamp: { bsonType: "string" }
});
orderDb.order_events.createIndex({ orderId: 1, timestamp: 1 });

// ---------------- payment_db ----------------
const paymentDb = db.getSiblingDB("payment_db");
makeCollection(paymentDb, "payments", ["paymentId", "orderId", "amount", "status"], {
  paymentId: { bsonType: "string" },
  orderId: { bsonType: "string" },
  status: { enum: ["PENDING", "COMPLETED", "FAILED", "REFUNDED"] }
});
paymentDb.payments.createIndex({ paymentId: 1 }, { unique: true });
paymentDb.payments.createIndex({ orderId: 1 }, { unique: true });

// ---------------- delivery_db ----------------
const deliveryDb = db.getSiblingDB("delivery_db");
makeCollection(deliveryDb, "drivers", ["driverId", "name", "available"], {
  driverId: { bsonType: "string" },
  name: { bsonType: "string" },
  available: { bsonType: "bool" }
});
deliveryDb.drivers.createIndex({ driverId: 1 }, { unique: true });
deliveryDb.drivers.createIndex({ available: 1 });
makeCollection(deliveryDb, "deliveries", ["deliveryId", "orderId", "status"], {
  deliveryId: { bsonType: "string" },
  orderId: { bsonType: "string" },
  driverId: { bsonType: "string" },
  status: { enum: ["ASSIGNED", "PICKED_UP", "IN_TRANSIT", "DELIVERED", "FAILED"] }
});
deliveryDb.deliveries.createIndex({ deliveryId: 1 }, { unique: true });
deliveryDb.deliveries.createIndex({ orderId: 1 }, { unique: true });
deliveryDb.deliveries.createIndex({ driverId: 1, status: 1 });

// ---------------- notification_db ----------------
const notificationDb = db.getSiblingDB("notification_db");
makeCollection(notificationDb, "notifications", ["notificationId", "recipientId", "recipientType", "channel", "message"], {
  notificationId: { bsonType: "string" },
  recipientId: { bsonType: "string" },
  recipientType: { enum: ["CUSTOMER", "RESTAURANT", "DRIVER"] },
  channel: { enum: ["EMAIL", "SMS", "PUSH"] }
});
notificationDb.notifications.createIndex({ recipientId: 1, sentAt: -1 });
notificationDb.notifications.createIndex({ orderId: 1 });

// ---------------- admin_db ----------------
const adminDb = db.getSiblingDB("admin_db");
makeCollection(adminDb, "reports", ["reportId", "reportType", "generatedAt"], {
  reportId: { bsonType: "string" },
  reportType: { enum: ["RESTAURANT_STATS", "DELIVERY_PERFORMANCE"] },
  generatedAt: { bsonType: "string" }
});
adminDb.reports.createIndex({ reportType: 1, generatedAt: -1 });

// ---------------- demo seed data (for the live defence) ----------------
customerDb.customers.insertMany([
  { customerId: "C001", name: "Anna Shikongo", email: "anna@example.com", phone: "+264811111111",
    addresses: [{ addressId: "A1", label: "Home", street: "12 Independence Ave", city: "Windhoek", region: "Khomas", isDefault: true }],
    createdAt: new Date().toISOString() }
]);
restaurantDb.restaurants.insertMany([
  { restaurantId: "R001", name: "Windhoek Grill", cuisine: "Braai", address: "Maerua Mall, Windhoek",
    openingHours: [{ day: "MON-SUN", open: "09:00", close: "22:00" }], isOpen: true, createdAt: new Date().toISOString() }
]);
restaurantDb.menu_items.insertMany([
  { itemId: "M001", restaurantId: "R001", name: "Beef Burger", description: "Grilled beef patty", price: 65.0, category: "Mains", stock: 50, available: true },
  { itemId: "M002", restaurantId: "R001", name: "Chips", price: 25.0, category: "Sides", stock: 100, available: true }
]);
deliveryDb.drivers.insertMany([
  { driverId: "D001", name: "Johannes Amutenya", phone: "+264812222222", vehicle: "Motorbike", available: true,
    currentLocation: { latitude: -22.5609, longitude: 17.0658 }, updatedAt: new Date().toISOString() }
]);

print("food-delivery databases, collections, indexes and seed data created");
