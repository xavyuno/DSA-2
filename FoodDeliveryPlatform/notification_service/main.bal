import ballerina/http;
import ballerina/log;
import ballerinax/kafka;

// Notification Service
// REST API: http://localhost:8085/notification
// Kafka topic consumed: orders.created (to send order confirmation alerts)

// --------------------
// Data types
// --------------------

type Order readonly & record {|
    string orderId;
    string customerId;
    string restaurantId;
    string[] items;
    string status;
|};

type NotificationPayload record {|
    string recipient;
    string message;
|};

// --------------------
// Notification REST API
// --------------------

service /notification on new http:Listener(8085) {

    resource function get health() returns string {
        return "notification-service is running";
    }

    // Endpoint to send a manual notification (e.g., promotional emails)
    resource function post send(@http:Payload NotificationPayload payload) returns json {
        log:printInfo(string `Sending manual notification to ${payload.recipient}: ${payload.message}`);
        return { status: "SUCCESS", message: "Notification sent successfully" };
    }
}

// --------------------
// Kafka consumer: orders.created
// --------------------
// Automatically sends an email to the customer and an alert to the restaurant when an order is placed.

listener kafka:Listener orderListener = new (kafka:DEFAULT_URL, {
    groupId: "notification-service-group",
    offsetReset: "latest",
    topics: ["orders.created"]
});

service on orderListener {
    remote function onConsumerRecord(Order[] orders) {
        foreach Order newOrder in orders {
            log:printInfo(string `[EMAIL] Sending order confirmation to Customer ${newOrder.customerId} for Order ${newOrder.orderId}`);
            log:printInfo(string `[ALERT] Notifying Restaurant ${newOrder.restaurantId} about new Order ${newOrder.orderId}`);
        }
    }
}