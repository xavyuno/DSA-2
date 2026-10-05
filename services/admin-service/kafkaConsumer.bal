import ballerinax/kafka;
import ballerina/io;

final kafka:ConsumerConfiguration consumerConfig = {
    groupId: kafkaGroupId,
    offsetReset: "earliest",
    topics: [ordersCreatedTopic]
};

final kafka:Consumer orderConsumer = check new (kafkaBroker, consumerConfig);

function runConsumer() returns error? {
    while true {
        kafka:AnydataConsumerRecord[] records = check orderConsumer->poll(1);

        foreach kafka:AnydataConsumerRecord consumerRecord in records {
            processRecord(consumerRecord);
        }
    }
}

function processRecord(kafka:AnydataConsumerRecord consumerRecord) {
    byte[]|error valueBytes = consumerRecord.value.ensureType();
    if valueBytes is error {
        io:println("Skipping record: bad value");
        return;
    }

    string payload = checkpanic string:fromBytes(valueBytes);
    io:println("Received: ", payload);

    json|error eventJson = payload.fromJsonString();
    if eventJson is error {
        io:println("Skipping record: invalid JSON");
        return;
    }

    OrderCreatedEvent|error event = eventJson.cloneWithType(OrderCreatedEvent);
    if event is error {
        io:println("Skipping record: missing fields");
        return;
    }

    error? result = incrementRestaurantOrderCount(event.restaurantId);
    if result is error {
        io:println("Failed to update MongoDB: ", result.message());
    } else {
        io:println("Updated count for restaurant ", event.restaurantId);
    }
}