import ballerinax/kafka;

kafka:ConsumerConfiguration consumerConfiguration = {
    groupId: "group-id",
    offsetReset: "earliest", 
    topics: ["kafka-topic"]
};

kafka:Consumer kafkaConsumer = check new (kafka:DEFAULT_URL, consumerConfiguration);