import ballerinax/kafka;
import ballerina/io;

final kafka:ConsumerConfiguration consumerConfig = {
    groupId: kafkaGroupId,
    offsetReset: "earliest",
    topics: ["orders.created"]
};

final kafka:Consumer orderConsumer = check new (kafkaBroker, consumerConfig);

function runConsumer() returns error? {
    while true {
        kafka:AnydataConsumerRecord[] records = check orderConsumer->poll(1);

        foreach kafka:AnydataConsumerRecord consumerRecord in records {
            byte[] valueBytes = check consumerRecord.value.ensureType();
            string payload = check string:fromBytes(valueBytes);
            io:println("Received: ", payload);

            json eventJson = check payload.fromJsonString();
            OrderCreatedEvent event = check eventJson.cloneWithType(OrderCreatedEvent);

            check incrementRestaurantOrderCount(event.restaurantId);
            io:println("Updated count for restaurant ", event.restaurantId);
        }
    }
}