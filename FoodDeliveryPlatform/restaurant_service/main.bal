import ballerina/http;
import ballerina/log;
import ballerinax/kafka;
import ballerinax/mongodb;

// Alex - Person 3: Restaurant Service & Inventory
// REST API: http://localhost:8083/restaurant
// Kafka topic consumed: orders.created

// --------------------
// Data types
// --------------------

type Restaurant record {|
    readonly string restaurantId;
    string name;
    string openingTime;
    string closingTime;
|};

type RestaurantInput record {|
    string restaurantId;
    string name;
    string openingTime;
    string closingTime;
|};

type OpeningHours record {|
    string openingTime;
    string closingTime;
|};

type MenuItem record {|
    readonly string restaurantId;
    readonly string itemId;
    string name;
    decimal price;
    int stock;
|};

type MenuItemInput record {|
    string itemId;
    string name;
    decimal price;
    int stock;
|};

type StockUpdate record {|
    int stock;
|};

type Order readonly & record {|
    string orderId;
    string customerId;
    string restaurantId;
    string[] items;
    string status;
|};

// --------------------
// Database Configuration
// --------------------
// Declarations for database resources
final mongodb:Client mongoClient;
final mongodb:Database db;
final mongodb:Collection restaurantsCol;
final mongodb:Collection menuItemsCol;

function init() returns error? {
    mongoClient = check new ({
        connection: "mongodb://localhost:27017"
    });
    db = check mongoClient->getDatabase("foodDeliveryDB");
    restaurantsCol = check db->getCollection("restaurants");
    menuItemsCol = check db->getCollection("menuItems");
}

// --------------------
// Restaurant REST API
// --------------------

@http:ServiceConfig {
    cors: {
        allowOrigins: ["http://localhost:3000", "http://127.0.0.1:3000"],
        allowMethods: ["GET", "POST", "PUT", "DELETE"],
        allowHeaders: ["Content-Type"]
    }
}
service /restaurant on new http:Listener(8083) {

    resource function get health() returns string {
        return "restaurant-service is running";
    }

    // Create a restaurant.
    resource function post restaurants(@http:Payload RestaurantInput input)
            returns Restaurant|http:Conflict|error {
        map<json> filter = {restaurantId: input.restaurantId};
        Restaurant? existing = check restaurantsCol->findOne(filter, targetType = Restaurant);
        if existing is Restaurant {
            return http:CONFLICT;
        }

        Restaurant restaurant = {
            restaurantId: input.restaurantId,
            name: input.name,
            openingTime: input.openingTime,
            closingTime: input.closingTime
        };

        _ = check restaurantsCol->insertOne(restaurant);
        return restaurant;
    }

    // View one restaurant.
    resource function get restaurants/[string restaurantId]()
            returns Restaurant|http:NotFound|error {
        map<json> filter = {restaurantId: restaurantId};
        Restaurant? restaurant = check restaurantsCol->findOne(filter, targetType = Restaurant);
        if restaurant is () {
            return http:NOT_FOUND;
        }
        return restaurant;
    }

    // Change opening and closing times.
    resource function put restaurants/[string restaurantId]/hours(
            @http:Payload OpeningHours hours)
            returns Restaurant|http:NotFound|error {
        map<json> filter = {restaurantId: restaurantId};
        Restaurant? current = check restaurantsCol->findOne(filter, targetType = Restaurant);
        if current is () {
            return http:NOT_FOUND;
        }

        mongodb:Update updateDoc = {
            "$set": {
                openingTime: hours.openingTime,
                closingTime: hours.closingTime
            }
        };

        _ = check restaurantsCol->updateOne(filter, updateDoc);
        
        Restaurant updated = {
            restaurantId: current.restaurantId,
            name: current.name,
            openingTime: hours.openingTime,
            closingTime: hours.closingTime
        };
        return updated;
    }

    // Add an item to a restaurant's menu.
    resource function post restaurants/[string restaurantId]/menu(
            @http:Payload MenuItemInput input)
            returns MenuItem|http:NotFound|http:Conflict|http:BadRequest|error {
        
        map<json> restFilter = {restaurantId: restaurantId};
        Restaurant? restaurant = check restaurantsCol->findOne(restFilter, targetType = Restaurant);
        if restaurant is () {
            return http:NOT_FOUND;
        }

        if input.price < 0d || input.stock < 0 {
            return http:BAD_REQUEST;
        }

        map<json> itemFilter = {restaurantId: restaurantId, itemId: input.itemId};
        MenuItem? existing = check menuItemsCol->findOne(itemFilter, targetType = MenuItem);
        if existing is MenuItem {
            return http:CONFLICT;
        }

        MenuItem item = {
            restaurantId: restaurantId,
            itemId: input.itemId,
            name: input.name,
            price: input.price,
            stock: input.stock
        };

        _ = check menuItemsCol->insertOne(item);
        return item;
    }

    // View a restaurant's menu.
    resource function get restaurants/[string restaurantId]/menu()
            returns MenuItem[]|http:NotFound|error {
        
        map<json> restFilter = {restaurantId: restaurantId};
        Restaurant? restaurant = check restaurantsCol->findOne(restFilter, targetType = Restaurant);
        if restaurant is () {
            return http:NOT_FOUND;
        }

        map<json> itemFilter = {restaurantId: restaurantId};
        stream<MenuItem, error?> itemStream = check menuItemsCol->find(itemFilter, targetType = MenuItem);
        MenuItem[] items = check from MenuItem item in itemStream
            select item;
        return items;
    }

    // Remove an item from the menu.
    resource function delete restaurants/[string restaurantId]/menu/[string itemId]()
            returns string|http:NotFound|error {
        
        map<json> filter = {restaurantId: restaurantId, itemId: itemId};
        MenuItem? current = check menuItemsCol->findOne(filter, targetType = MenuItem);
        if current is () {
            return http:NOT_FOUND;
        }

        _ = check menuItemsCol->deleteOne(filter);
        return "menu item removed";
    }

    // View current inventory.
    resource function get restaurants/[string restaurantId]/inventory()
            returns MenuItem[]|http:NotFound|error {
        
        map<json> restFilter = {restaurantId: restaurantId};
        Restaurant? restaurant = check restaurantsCol->findOne(restFilter, targetType = Restaurant);
        if restaurant is () {
            return http:NOT_FOUND;
        }

        map<json> itemFilter = {restaurantId: restaurantId};
        stream<MenuItem, error?> itemStream = check menuItemsCol->find(itemFilter, targetType = MenuItem);
        MenuItem[] items = check from MenuItem item in itemStream
            select item;
        return items;
    }

    // Set the current stock after a restock or correction.
    resource function put restaurants/[string restaurantId]/inventory/[string itemId](
            @http:Payload StockUpdate update)
            returns MenuItem|http:NotFound|http:BadRequest|error {
        
        if update.stock < 0 {
            return http:BAD_REQUEST;
        }

        map<json> filter = {restaurantId: restaurantId, itemId: itemId};
        MenuItem? current = check menuItemsCol->findOne(filter, targetType = MenuItem);
        if current is () {
            return http:NOT_FOUND;
        }

        mongodb:Update updateDoc = {
            "$set": {
                stock: update.stock
            }
        };

        _ = check menuItemsCol->updateOne(filter, updateDoc);
        
        MenuItem updated = {
            restaurantId: current.restaurantId,
            itemId: current.itemId,
            name: current.name,
            price: current.price,
            stock: update.stock
        };
        return updated;
    }
}

// --------------------
// Kafka consumer: orders.created
// --------------------

listener kafka:Listener orderListener = new (kafka:DEFAULT_URL, {
    groupId: "restaurant-service-group",
    offsetReset: "latest",
    topics: ["orders.created"]
});

service on orderListener {
    remote function onConsumerRecord(Order[] orders) {
        foreach Order newOrder in orders {
            log:printInfo(string `Received order ${newOrder.orderId}`);

            foreach string itemId in newOrder.items {
                do {
                    map<json> filter = {restaurantId: newOrder.restaurantId, itemId: itemId};
                    MenuItem? current = check menuItemsCol->findOne(filter, targetType = MenuItem);

                    if current is () {
                        log:printWarn(string `Item ${itemId} was not found for restaurant ${newOrder.restaurantId}`);
                        continue;
                    }

                    if current.stock <= 0 {
                        log:printWarn(string `Item ${itemId} is out of stock`);
                        continue;
                    }

                    int newStock = current.stock - 1;
                    mongodb:Update updateDoc = {
                        "$set": {
                            stock: newStock
                        }
                    };

                    _ = check menuItemsCol->updateOne(filter, updateDoc);
                    log:printInfo(string `Stock for ${itemId} is now ${newStock}`);
                } on fail error err {
                    log:printError(string `Error processing item ${itemId} stock update: ${err.message()}`);
                }
            }
        }
    }
}