import ballerina/http;
import ballerina/log;
import ballerinax/kafka;
import ballerinax/mongodb;

type Order record {|
    readonly string orderId;
    string customerId;
    string restaurantId;
    string[] items;
    string status;
    string? driverId = ();
|};

type OrderInput record {|
    string orderId;
    string customerId;
    string restaurantId;
    string[] items;
|};

type StatusUpdate record {|
    string status;
    string? driverId = ();
|};

final mongodb:Client mongoClient;
final mongodb:Database db;
final mongodb:Collection ordersCol;
final kafka:Producer orderProducer;

function init() returns error? {
    mongoClient = check new ({
        connection: "mongodb://localhost:27017"
    });
    db = check mongoClient->getDatabase("foodDeliveryDB");
    ordersCol = check db->getCollection("orders");
    orderProducer = check new (kafka:DEFAULT_URL);
}

function getTopicForStatus(string status) returns string {
    match status {
        "CONFIRMED" => { return "orders.confirmed"; }
        "PREPARING" => { return "orders.preparing"; }
        "READY" => { return "orders.ready"; }
        "OUT_FOR_DELIVERY" => { return "orders.delivering"; }
        "DELIVERED" => { return "orders.completed"; }
        "CANCELLED" => { return "orders.cancelled"; }
        _ => { return "orders.updated"; }
    }
}

service /orders on new http:Listener(8081) {

    resource function get health() returns string {
        return "order-service is running";
    }

    resource function post .(@http:Payload OrderInput input)
            returns Order|http:Conflict|http:InternalServerError|error {
        map<json> filter = {orderId: input.orderId};
        Order? existing = check ordersCol->findOne(filter, targetType = Order);
        if existing is Order {
            return http:CONFLICT;
        }

        Order newOrder = {
            orderId: input.orderId,
            customerId: input.customerId,
            restaurantId: input.restaurantId,
            items: input.items,
            status: "CREATED"
        };

        _ = check ordersCol->insertOne(newOrder);

        kafka:Error? result = orderProducer->send({
            topic: "orders.created",
            value: newOrder
        });

        if result is kafka:Error {
            log:printError("Failed to publish orders.created", 'error = result);
            return http:INTERNAL_SERVER_ERROR;
        }

        log:printInfo("Order created: " + newOrder.orderId);
        return newOrder;
    }

    resource function patch [string id]/status(@http:Payload StatusUpdate updatePayload)
            returns Order|http:NotFound|http:InternalServerError|error {
        map<json> filter = {orderId: id};
        Order? existingOrder = check ordersCol->findOne(filter, targetType = Order);
        if existingOrder is () {
            return http:NOT_FOUND;
        }

        mongodb:Update updateDoc = {
            "$set": {
                status: updatePayload.status,
                driverId: updatePayload.driverId ?: existingOrder.driverId
            }
        };

        _ = check ordersCol->updateOne(filter, updateDoc);

        Order updatedOrder = {
            orderId: id,
            customerId: existingOrder.customerId,
            restaurantId: existingOrder.restaurantId,
            items: existingOrder.items,
            status: updatePayload.status,
            driverId: updatePayload.driverId ?: existingOrder.driverId
        };

        string targetTopic = getTopicForStatus(updatePayload.status);

        kafka:Error? result = orderProducer->send({
            topic: targetTopic,
            value: updatedOrder
        });

        if result is kafka:Error {
            log:printError("Failed to publish order status event", 'error = result);
            return http:INTERNAL_SERVER_ERROR;
        }

        log:printInfo("Order updated: " + id);
        return updatedOrder;
    }

    resource function get [string id]() returns Order|http:NotFound|error {
        map<json> filter = {orderId: id};
        Order? ord = check ordersCol->findOne(filter, targetType = Order);
        if ord is () {
            return http:NOT_FOUND;
        }
        return ord;
    }

    resource function get .() returns Order[]|error {
        stream<Order, error?> orderStream = check ordersCol->find({}, targetType = Order);
        return check from Order o in orderStream select o;
    }
}