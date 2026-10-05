// Reference Ballerina records matching the MongoDB collections created by mongo-init/init.js.
// Teammates: copy the records your service needs into your own package.
// Database per service: customer_db, restaurant_db, order_db, payment_db, delivery_db, notification_db, admin_db

// ---------- customer_db.customers ----------
public type Address record {|
    string addressId;
    string label;
    string street;
    string city;
    string region;
    boolean isDefault = false;
|};

public type Customer record {|
    string customerId;
    string name;
    string email;
    string phone?;
    Address[] addresses = [];
    string createdAt?;
|};

// ---------- restaurant_db.restaurants / menu_items ----------
public type OpeningHours record {|
    string day;
    string open;
    string close;
|};

public type Restaurant record {|
    string restaurantId;
    string name;
    string cuisine?;
    string address?;
    OpeningHours[] openingHours = [];
    boolean isOpen = true;
    string createdAt?;
|};

public type MenuItem record {|
    string itemId;
    string restaurantId;
    string name;
    string description?;
    decimal price;
    string category?;
    int stock = 0;
    boolean available = true;
|};

// ---------- order_db.orders (defined in database.bal) / order_events ----------
public type OrderEvent record {|
    string orderId;
    string fromStatus?;
    string toStatus;
    string timestamp;
|};

// ---------- payment_db.payments ----------
public type Payment record {|
    string paymentId;
    string orderId;
    string customerId?;
    decimal amount;
    string method?;
    string status; // PENDING | COMPLETED | FAILED | REFUNDED
    string createdAt?;
|};

// ---------- delivery_db.drivers / deliveries ----------
public type GeoLocation record {|
    decimal latitude;
    decimal longitude;
|};

public type Driver record {|
    string driverId;
    string name;
    string phone?;
    string vehicle?;
    boolean available = true;
    GeoLocation currentLocation?;
    string updatedAt?;
|};

public type Delivery record {|
    string deliveryId;
    string orderId;
    string driverId?;
    string status; // ASSIGNED | PICKED_UP | IN_TRANSIT | DELIVERED | FAILED
    string assignedAt?;
    string deliveredAt?;
|};

// ---------- notification_db.notifications ----------
public type Notification record {|
    string notificationId;
    string recipientId;
    string recipientType; // CUSTOMER | RESTAURANT | DRIVER
    string channel;       // EMAIL | SMS | PUSH
    string message;
    string orderId?;
    string sentAt?;
    boolean read = false;
|};

// ---------- admin_db.reports ----------
public type Report record {|
    string reportId;
    string reportType; // RESTAURANT_STATS | DELIVERY_PERFORMANCE
    string generatedAt;
    map<json> data;
|};
