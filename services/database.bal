import ballerinax/mongodb;

// ---------- Data Model ----------
// Shared across the whole module (main.bal uses this too, so do NOT redefine it there)
public type Order record {|
    string orderId;
    string customerId;
    string restaurantId;
    string[] items;
    decimal totalAmount;
    string status;
    string createdAt?;
|};

// ---------- Configuration ----------
// Override in Config.toml so it works both locally and inside Docker Compose
configurable string mongoHost = "mongodb";
configurable int mongoPort = 27017;
configurable string dbName = "food_delivery_db";

// ---------- MongoDB Client ----------
// Must be `final` so it can be used from isolated functions
final mongodb:Client mongoClient = check new ({
    connection: {
        serverAddress: {
            host: mongoHost,
            port: mongoPort
        }
    }
});

# Saves an order document to the `orders` collection.
#
# + orderDoc - The Order record to insert
# + return - An error if the insertion fails
public isolated function saveOrderToDb(Order orderDoc) returns error? {
    mongodb:Database db = check mongoClient->getDatabase(dbName);
    mongodb:Collection ordersCol = check db->getCollection("orders");
    check ordersCol->insertOne(orderDoc);
}