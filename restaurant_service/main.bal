import ballerina/log;
import ballerinax/kafka;

// 1. Define the Kafka Consumer Configuration
kafka:ConsumerConfiguration consumerConfig = {
    groupId: "restaurant-group",
    topics: ["orders.created"],
    offsetReset: kafka:OFFSET_RESET_EARLIEST
};

// 2. Initialize the Kafka Listener
listener kafka:Listener kafkaListener = check new (kafka:DEFAULT_URL, consumerConfig);

// 3. Define the data structure for an Order
type Order record {
    string orderId;
    string customerId;
    string restaurantId;
    string[] items;
    string status;
};

// 4. Attach the service to the Kafka listener
service on kafkaListener {

    // Remote function triggered on new incoming messages
    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach var kafkaRecord in records {
            // Convert byte[] payload to string and parse JSON
            string payloadStr = check string:fromBytes(kafkaRecord.value);
            json jsonPayload = check payloadStr.fromJsonString();
            
            // Clone JSON into the Order record type
            Order ord = check jsonPayload.cloneWithType(Order);

            // Logging received order details
            log:printInfo("========================================");
            log:printInfo("RECEIVED NEW ORDER IN RESTAURANT SERVICE");
            log:printInfo("Order ID: " + ord.orderId);
            log:printInfo("Customer ID: " + ord.customerId);
            log:printInfo("Restaurant ID: " + ord.restaurantId);
            log:printInfo("Status: " + ord.status);
            log:printInfo("========================================");
        }
    }
}