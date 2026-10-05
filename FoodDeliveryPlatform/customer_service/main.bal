import ballerina/http;
import ballerinax/mongodb;

// Customer Service
// REST API: http://localhost:8082/customer

// --------------------
// Data types
// --------------------

type Customer record {|
    readonly string customerId;
    string name;
    string email;
    string phone;
    string address;
|};

type CustomerInput record {|
    string customerId;
    string name;
    string email;
    string phone;
    string address;
|};

// --------------------
// Database Configuration
// --------------------
final mongodb:Client mongoClient;
final mongodb:Database db;
final mongodb:Collection customersCol;

function init() returns error? {
    mongoClient = check new ({
        connection: "mongodb://localhost:27017"
    });
    db = check mongoClient->getDatabase("foodDeliveryDB");
    customersCol = check db->getCollection("customers");
}

// --------------------
// Customer REST API
// --------------------

service /customer on new http:Listener(8082) {

    // Quick check for DevOps and testing.
    resource function get health() returns string {
        return "customer-service is running";
    }

    // Register a new customer.
    resource function post customers(@http:Payload CustomerInput input)
            returns Customer|http:Conflict|error {
        map<json> filter = {customerId: input.customerId};
        Customer? existing = check customersCol->findOne(filter, targetType = Customer);
        if existing is Customer {
            return http:CONFLICT;
        }

        Customer newCustomer = {
            customerId: input.customerId,
            name: input.name,
            email: input.email,
            phone: input.phone,
            address: input.address
        };

        _ = check customersCol->insertOne(newCustomer);
        return newCustomer;
    }

    // View a customer's profile.
    resource function get customers/[string customerId]()
            returns Customer|http:NotFound|error {
        map<json> filter = {customerId: customerId};
        Customer? customer = check customersCol->findOne(filter, targetType = Customer);
        if customer is () {
            return http:NOT_FOUND;
        }
        return customer;
    }

    // Update a customer's profile.
    resource function put customers/[string customerId](@http:Payload CustomerInput input)
            returns Customer|http:NotFound|http:BadRequest|error {
        if customerId != input.customerId {
            return http:BAD_REQUEST;
        }

        map<json> filter = {customerId: customerId};
        Customer? current = check customersCol->findOne(filter, targetType = Customer);
        if current is () {
            return http:NOT_FOUND;
        }

        mongodb:Update updateDoc = {
            "$set": {
                name: input.name,
                email: input.email,
                phone: input.phone,
                address: input.address
            }
        };

        _ = check customersCol->updateOne(filter, updateDoc);

        Customer updated = {
            customerId: customerId,
            name: input.name,
            email: input.email,
            phone: input.phone,
            address: input.address
        };

        return updated;
    }
}