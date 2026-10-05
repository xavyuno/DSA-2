import ballerina/http;
import ballerina/log;
import ballerinax/kafka;

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

// This matches Person 1's Order Service.
// Every string in items is treated as one menu item ID.
type Order readonly & record {|
    string orderId;
    string customerId;
    string restaurantId;
    string[] items;
    string status;
|};

// --------------------
// Temporary in-memory storage
// --------------------
// The Database Lead can replace these tables with MongoDB later.

table<Restaurant> key(restaurantId) restaurants = table [];
table<MenuItem> key(restaurantId, itemId) menuItems = table [];

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

    // Quick check for the DevOps person and for testing.
    resource function get health() returns string {
        return "restaurant-service is running";
    }

    // Create a restaurant.
    resource function post restaurants(@http:Payload RestaurantInput input)
            returns Restaurant|http:Conflict {
        Restaurant? existing = restaurants[input.restaurantId];
        if existing is Restaurant {
            return http:CONFLICT;
        }

        Restaurant restaurant = {
            restaurantId: input.restaurantId,
            name: input.name,
            openingTime: input.openingTime,
            closingTime: input.closingTime
        };

        restaurants.add(restaurant);
        return restaurant;
    }

    // View one restaurant.
    resource function get restaurants/[string restaurantId]()
            returns Restaurant|http:NotFound {
        Restaurant? restaurant = restaurants[restaurantId];
        if restaurant is () {
            return http:NOT_FOUND;
        }
        return restaurant;
    }

    // Change opening and closing times.
    resource function put restaurants/[string restaurantId]/hours(
            @http:Payload OpeningHours hours)
            returns Restaurant|http:NotFound {
        Restaurant? current = restaurants[restaurantId];
        if current is () {
            return http:NOT_FOUND;
        }

        Restaurant updated = {
            restaurantId: current.restaurantId,
            name: current.name,
            openingTime: hours.openingTime,
            closingTime: hours.closingTime
        };

        restaurants.put(updated);
        return updated;
    }

    // Add an item to a restaurant's menu.
    resource function post restaurants/[string restaurantId]/menu(
            @http:Payload MenuItemInput input)
            returns MenuItem|http:NotFound|http:Conflict|http:BadRequest {
        Restaurant? restaurant = restaurants[restaurantId];
        if restaurant is () {
            return http:NOT_FOUND;
        }

        if input.price < 0d || input.stock < 0 {
            return http:BAD_REQUEST;
        }

        MenuItem? existing = menuItems[restaurantId, input.itemId];
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

        menuItems.add(item);
        return item;
    }

    // View a restaurant's menu.
    resource function get restaurants/[string restaurantId]/menu()
            returns MenuItem[]|http:NotFound {
        Restaurant? restaurant = restaurants[restaurantId];
        if restaurant is () {
            return http:NOT_FOUND;
        }

        MenuItem[] items = from MenuItem item in menuItems
            where item.restaurantId == restaurantId
            select item;
        return items;
    }

    // Remove an item from the menu.
    resource function delete restaurants/[string restaurantId]/menu/[string itemId]()
            returns string|http:NotFound {
        MenuItem? current = menuItems[restaurantId, itemId];
        if current is () {
            return http:NOT_FOUND;
        }

        _ = menuItems.remove([restaurantId, itemId]);
        return "menu item removed";
    }

    // View current inventory.
    resource function get restaurants/[string restaurantId]/inventory()
            returns MenuItem[]|http:NotFound {
        Restaurant? restaurant = restaurants[restaurantId];
        if restaurant is () {
            return http:NOT_FOUND;
        }

        MenuItem[] items = from MenuItem item in menuItems
            where item.restaurantId == restaurantId
            select item;
        return items;
    }

    // Set the current stock after a restock or correction.
    resource function put restaurants/[string restaurantId]/inventory/[string itemId](
            @http:Payload StockUpdate update)
            returns MenuItem|http:NotFound|http:BadRequest {
        if update.stock < 0 {
            return http:BAD_REQUEST;
        }

        MenuItem? current = menuItems[restaurantId, itemId];
        if current is () {
            return http:NOT_FOUND;
        }

        MenuItem updated = {
            restaurantId: current.restaurantId,
            itemId: current.itemId,
            name: current.name,
            price: current.price,
            stock: update.stock
        };

        menuItems.put(updated);
        return updated;
    }
}

// --------------------
// Kafka consumer: orders.created
// --------------------
// Person 1 publishes an Order to orders.created.
// Example items: ["BURGER-01", "BURGER-01", "CHIPS-01"]
// means 2 burgers and 1 chips.

listener kafka:Listener orderListener = new (kafka:DEFAULT_URL, {
    groupId: "restaurant-service-group",
    offsetReset: "latest",
    topics: ["orders.created"]
});

service on orderListener {
    remote function onConsumerRecord(Order[] orders) {
        foreach Order order in orders {
            log:printInfo(string `Received order ${order.orderId}`);

            foreach string itemId in order.items {
                MenuItem? current = menuItems[order.restaurantId, itemId];

                if current is () {
                    log:printWarn(string `Item ${itemId} was not found for restaurant ${order.restaurantId}`);
                    continue;
                }

                if current.stock <= 0 {
                    log:printWarn(string `Item ${itemId} is out of stock`);
                    continue;
                }

                MenuItem updated = {
                    restaurantId: current.restaurantId,
                    itemId: current.itemId,
                    name: current.name,
                    price: current.price,
                    stock: current.stock - 1
                };

                menuItems.put(updated);
                log:printInfo(string `Stock for ${itemId} is now ${updated.stock}`);
            }
        }
    }
}
