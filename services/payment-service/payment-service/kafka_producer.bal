import ballerinax/kafka;

final kafka:Producer kafkaProducer = check new (kafkaBootstrapServers, {
    clientId: kafkaClientId,
    acks: kafka:ACKS_ALL,
    retryCount: 3
});

// Sends the payments.completed event to Kafka.
function publishPaymentCompleted(PaymentEvent event) returns error? {
    check kafkaProducer->send({
        topic: paymentsCompletedTopic,
        key: event.orderId.toBytes(),
        value: event.toJsonString().toBytes()
    });
    check kafkaProducer->'flush();
}
