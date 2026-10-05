import ballerina/http;
import ballerina/log;
import ballerinax/mongodb;

// Admin Service
// REST API: http://localhost:8087/admin

// --------------------
// Data types
// --------------------

type PlatformStats record {|
    int totalRestaurants;
    int totalDrivers;
    int totalOrdersProcessed;
    string systemStatus;
|};

type SystemConfig record {|
    readonly string key;
    string value;
|};

// --------------------
// Database Configuration
// --------------------
final mongodb:Client mongoClient;
final mongodb:Database db;
final mongodb:Collection restaurantsCol;
final mongodb:Collection driversCol;
final mongodb:Collection ordersCol;
final mongodb:Collection configCol;

function init() returns error? {
    mongoClient = check new ({
        connection: "mongodb://localhost:27017"
    });
    db = check mongoClient->getDatabase("foodDeliveryDB");
    
    restaurantsCol = check db->getCollection("restaurants");
    driversCol = check db->getCollection("drivers");
    ordersCol = check db->getCollection("orders");
    configCol = check db->getCollection("system_config");
}

// --------------------
// Admin REST API
// --------------------

service /admin on new http:Listener(8087) {

    resource function get health() returns string {
        return "admin-service is running";
    }

    // View live platform statistics from MongoDB
    resource function get stats() returns PlatformStats|error {
        log:printInfo("Admin dashboard requested live platform stats.");

        // Count total documents across microservice collections
        int restaurantsCount = check restaurantsCol->countDocuments({});
        int driversCount = check driversCol->countDocuments({});
        int ordersCount = check ordersCol->countDocuments({});

        // Fetch maintenance status from config collection
        map<json> filter = {key: "maintenance_mode"};
        SystemConfig? config = check configCol->findOne(filter, targetType = SystemConfig);
        
        string mode = "All systems operational";
        if config is SystemConfig && config.value == "on" {
            mode = "System currently in MAINTENANCE MODE";
        }

        PlatformStats stats = {
            totalRestaurants: restaurantsCount,
            totalDrivers: driversCount,
            totalOrdersProcessed: ordersCount,
            systemStatus: mode
        };

        return stats;
    }

    // Toggle system maintenance mode and persist in MongoDB
    resource function post maintenance/[string status]() returns json|error {
        if status != "on" && status != "off" {
            return { status: "ERROR", message: "Invalid status. Use 'on' or 'off'" };
        }

        map<json> filter = {key: "maintenance_mode"};
        mongodb:Update updateDoc = {
            "$set": {
                value: status
            }
        };

        // Pass options using UpdateOptions record with upsert field
        mongodb:UpdateOptions options = {
            upsert: true
        };

        mongodb:UpdateResult _ = check configCol->updateOne(
            filter, 
            updateDoc, 
            options
        );

        if status == "on" {
            log:printWarn("Admin has enabled MAINTENANCE MODE.");
            return { status: "SUCCESS", message: "Maintenance mode enabled" };
        } else {
            log:printInfo("Admin has disabled MAINTENANCE MODE.");
            return { status: "SUCCESS", message: "Maintenance mode disabled" };
        }
    }
}