import ballerina/http;
import ballerina/log;
import ballerinax/kafka;

// Delivery Service
// REST API: http://localhost:8084/delivery
// Kafka topic consumed: orders.created (to automatically assign a driver)

// --------------------
// Data types
// --------------------

type Driver record {|
    readonly string driverId;
    string name;
    string phone;
    boolean available;
|};

type DriverInput record {|
    string driverId;
    string name;
    string phone;
|};

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
// TODO: Database Lead - Please replace this in-memory table with MongoDB.
table<Driver> key(driverId) drivers = table [];

// --------------------
// Delivery REST API
// --------------------

service /delivery on new http:Listener(8084) {

    resource function get health() returns string {
        return "delivery-service is running";
    }

    // Register a new driver.
    resource function post drivers(@http:Payload DriverInput input)
            returns Driver|http:Conflict {
        Driver? existing = drivers[input.driverId];
        if existing is Driver {
            return http:CONFLICT;
        }

        Driver driver = {
            driverId: input.driverId,
            name: input.name,
            phone: input.phone,
            available: true
        };

        drivers.add(driver);
        return driver;
    }

    // View all drivers.
    resource function get drivers() returns Driver[] {
        return from Driver d in drivers select d;
    }

    // View a specific driver.
    resource function get drivers/[string driverId]()
            returns Driver|http:NotFound {
        Driver? driver = drivers[driverId];
        if driver is () {
            return http:NOT_FOUND;
        }
        return driver;
    }
}

// --------------------
// Kafka consumer: orders.created
// --------------------
// When an order is created, the delivery service finds an available driver and assigns them.

listener kafka:Listener orderListener = new (kafka:DEFAULT_URL, {
    groupId: "delivery-service-group",
    offsetReset: "latest",
    topics: ["orders.created"]
});

service on orderListener {
    remote function onConsumerRecord(Order[] orders) {
        foreach Order newOrder in orders {
            log:printInfo(string `Delivery Service: Received order ${newOrder.orderId}. Finding an available driver...`);

            // Find the first available driver
            Driver? availableDriver = ();
            foreach Driver d in drivers {
                if d.available {
                    availableDriver = d;
                    break;
                }
            }

            if availableDriver is Driver {
                log:printInfo(string `Assigned driver ${availableDriver.driverId} to order ${newOrder.orderId}`);
                
                // Mark driver as unavailable
                Driver updatedDriver = {
                    driverId: availableDriver.driverId,
                    name: availableDriver.name,
                    phone: availableDriver.phone,
                    available: false
                };
                drivers.put(updatedDriver);
            } else {
                log:printWarn(string `No available drivers for order ${newOrder.orderId}`);
            }
        }
    }
}