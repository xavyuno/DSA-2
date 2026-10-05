import ballerinax/mongodb;

final mongodb:Client mongoClient = check new ({connection: mongoUri});

isolated function getStatsCollection() returns mongodb:Collection|error {
    mongodb:Database adminDb = check mongoClient->getDatabase("admin");
    return adminDb->getCollection("restaurant_stats");
}

isolated function incrementRestaurantOrderCount(string restaurantId) returns error? {
    mongodb:Collection collection = check getStatsCollection();
    RestaurantStats? existing = check collection->findOne({restaurantId: restaurantId});

    if existing is RestaurantStats {
        int newCount = existing.orderCount + 1;
        mongodb:UpdateResult result = check collection->updateOne(
            {restaurantId: restaurantId},
            {set: {orderCount: newCount}}
        );
    } else {
        RestaurantStats newStats = {
            restaurantId: restaurantId,
            orderCount: 1
        };
        check collection->insertOne(newStats);
    }
}

isolated function getAllRestaurantStats() returns RestaurantStats[]|error {
    mongodb:Collection collection = check getStatsCollection();
    stream<RestaurantStats, error?>|error results = collection->find({});

    if results is error {
        return results;
    }

    RestaurantStats[] list = [];
    foreach RestaurantStats s in results {
        list.push(s);
    }
    return list;
}