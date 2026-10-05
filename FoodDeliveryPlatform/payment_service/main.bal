import ballerina/http;
import ballerina/log;
import ballerinax/kafka;
import ballerinax/mongodb;

// Payment Service
// REST API: http://localhost:8086/payment
// Kafka topic consumed: orders.created (to automatically charge for the order)

// --------------------
// Data types
// --------------------

type Payment record {|
    readonly string paymentId;
    string orderId;
    string customerId;
    decimal amount;
    string status; // e.g., "SUCCESS", "FAILED"
|};

type PaymentInput record {|
    string paymentId;
    string orderId;
    string customerId;
    decimal amount;
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
final mongodb:Client mongoClient;
final mongodb:Database db;
final mongodb:Collection paymentsCol;

function init() returns error? {
    mongoClient = check new ({
        connection: "mongodb://localhost:27017"
    });
    db = check mongoClient->getDatabase("foodDeliveryDB");
    paymentsCol = check db->getCollection("payments");
}

// --------------------
// Payment REST API
// --------------------

service /payment on new http:Listener(8086) {

    resource function get health() returns string {
        return "payment-service is running";
    }

    // Manually process a payment (e.g., if an order is placed over the phone)
    resource function post payments(@http:Payload PaymentInput input)
            returns Payment|http:Conflict|error {
        map<json> filter = {paymentId: input.paymentId};
        Payment? existing = check paymentsCol->findOne(filter, targetType = Payment);
        if existing is Payment {
            return http:CONFLICT;
        }

        Payment newPayment = {
            paymentId: input.paymentId,
            orderId: input.orderId,
            customerId: input.customerId,
            amount: input.amount,
            status: "SUCCESS" // Simulating a successful payment
        };

        _ = check paymentsCol->insertOne(newPayment);
        return newPayment;
    }

    // View a payment by ID.
    resource function get payments/[string paymentId]()
            returns Payment|http:NotFound|error {
        map<json> filter = {paymentId: paymentId};
        Payment? payment = check paymentsCol->findOne(filter, targetType = Payment);
        if payment is () {
            return http:NOT_FOUND;
        }
        return payment;
    }
}

// --------------------
// Kafka consumer: orders.created
// --------------------
// Automatically attempts to charge the customer when an order is placed.

listener kafka:Listener orderListener = new (kafka:DEFAULT_URL, {
    groupId: "payment-service-group",
    offsetReset: "latest",
    topics: ["orders.created"]
});

service on orderListener {
    remote function onConsumerRecord(Order[] orders) {
        foreach Order newOrder in orders {
            do {
                log:printInfo(string `Payment Service: Received order ${newOrder.orderId}. Processing payment for customer ${newOrder.customerId}...`);
                
                // Simulate processing a payment of $20.00 for the order
                string generatedPaymentId = "pay-" + newOrder.orderId;
                
                Payment processedPayment = {
                    paymentId: generatedPaymentId,
                    orderId: newOrder.orderId,
                    customerId: newOrder.customerId,
                    amount: 20.00d, // Flat rate simulation
                    status: "SUCCESS"
                };
                
                _ = check paymentsCol->insertOne(processedPayment);
                log:printInfo(string `Payment ${generatedPaymentId} successful for order ${newOrder.orderId}`);
            } on fail error err {
                log:printError(string `Failed to record payment for order ${newOrder.orderId}: ${err.message()}`);
            }
        }
    }
}