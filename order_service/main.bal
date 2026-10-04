import ballerina/http;
import ballerinax/kafka;

// Initialize the Kafka Producer directly with the bootstrap server URL
final kafka:Producer orderProducer = check new (kafka:DEFAULT_URL); // defaults to "localhost:9092"

// Define the data structure for an Order
type Order record {
    string orderId;
    string customerId;
    string restaurantId;
    string[] items;
    string status;
};

// Define the REST API listener on port 8081
service / on new http:Listener(8081) {

    // Endpoint: POST /orders
    resource function post orders(Order incomingOrder) returns json|http:InternalServerError {
        
        // 1. Set the initial status of the order to CREATED
        incomingOrder.status = "CREATED";

        // 2. Send the message payload to Kafka
        kafka:Error? result = orderProducer->send({
            topic: "orders.created",
            value: incomingOrder.toJsonString().toBytes()
        });

        if result is kafka:Error {
            // Return http:InternalServerError on Kafka failure
            http:InternalServerError errResponse = {
                body: { status: "FAILED", message: "Could not process order at this time" }
            };
            return errResponse;
        }

        // 3. Convert record to JSON using .toJson()
        json responsePayload = { 
            status: "SUCCESS", 
            message: "Order placed successfully!", 
            orderData: incomingOrder.toJson() 
        };
        
        return responsePayload;
    }
}