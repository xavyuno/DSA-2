import ballerina/http;
import ballerina/log;
import ballerina/observe;
import ballerina/time;
import ballerinax/kafka;
import ballerinax/prometheus as _; // enables the Prometheus metrics endpoint

// ---------- Configuration ----------
configurable string kafkaBootstrap = "kafka:9092";
configurable string ordersCreatedTopic = "orders.created";

// ---------- Observability: Prometheus Counters ----------
final observe:Counter totalOrdersCounter = new ("orders_created_total", "Total number of food delivery orders placed");
final observe:Counter failedOrdersCounter = new ("orders_failed_total", "Total number of failed food delivery orders");

function init() returns error? {
    // Counters must be registered, otherwise they never show up in Prometheus
    check totalOrdersCounter.register();
    check failedOrdersCounter.register();
}

// ---------- Kafka Producer ----------
final kafka:Producer orderProducer = check new (kafkaBootstrap);

// ---------- REST API ----------
service / on new http:Listener(8081) {

    # POST /orders - Creates an order, persists it to MongoDB and emits an `orders.created` event
    resource function post orders(@http:Payload Order incomingOrder) returns json|http:InternalServerError {

        // Step 1: Set initial order state
        incomingOrder.status = "CREATED";
        incomingOrder.createdAt = time:utcToString(time:utcNow());

        // Step 2: Save the order to MongoDB (helper lives in database.bal)
        error? dbResult = saveOrderToDb(incomingOrder);
        if dbResult is error {
            log:printError("Failed to save order", dbResult, orderId = incomingOrder.orderId);
            failedOrdersCounter.increment();
            return {
                body: {status: "FAILED", message: "Database error: Unable to save order"}
            };
        }

        // Step 3: Publish the event to Kafka (keyed by orderId so one order's events stay in one partition)
        kafka:Error? kafkaResult = orderProducer->send({
            topic: ordersCreatedTopic,
            key: incomingOrder.orderId.toBytes(),
            value: incomingOrder.toJsonString().toBytes()
        });
        if kafkaResult is kafka:Error {
            log:printError("Failed to publish order event", kafkaResult, orderId = incomingOrder.orderId);
            failedOrdersCounter.increment();
            return {
                body: {status: "FAILED", message: "Event streaming error: Could not publish order event"}
            };
        }

        // Step 4: Track success metric
        totalOrdersCounter.increment();

        // Step 5: Return success response
        return {
            status: "SUCCESS",
            message: "Order placed successfully!",
            orderData: incomingOrder.toJson()
        };
    }
}