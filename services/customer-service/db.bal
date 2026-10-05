import ballerinax/mongodb;

const string CUSTOMERS = "customers";
const string ADDRESSES = "addresses";
const string ORDERS = "orders";

final map<json> & readonly HIDE_MONGO_ID = {"_id": 0};

final mongodb:Client mongoClient = check new ({connection: mongoUrl});

function getCollection(string name) returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase(mongoDatabase);
    return db->getCollection(name);
}

function dbInsertCustomer(Customer customer) returns error? {
    mongodb:Collection col = check getCollection(CUSTOMERS);
    check col->insertOne(customer);
}

function dbFindCustomerById(string id) returns Customer|error? {
    mongodb:Collection col = check getCollection(CUSTOMERS);
    return col->findOne({id: id}, {}, HIDE_MONGO_ID, Customer);
}

function dbFindCustomerByEmail(string email) returns Customer|error? {
    mongodb:Collection col = check getCollection(CUSTOMERS);
    return col->findOne({email: email}, {}, HIDE_MONGO_ID, Customer);
}

function dbUpdateCustomer(string id, map<json> changes) returns int|error {
    mongodb:Collection col = check getCollection(CUSTOMERS);
    mongodb:UpdateResult result = check col->updateOne({id: id}, {set: changes});
    return result.matchedCount;
}

function dbDeleteCustomer(string id) returns int|error {
    mongodb:Collection customers = check getCollection(CUSTOMERS);
    mongodb:DeleteResult result = check customers->deleteOne({id: id});

    mongodb:Collection addresses = check getCollection(ADDRESSES);
    _ = check addresses->deleteMany({customerId: id});
    return result.deletedCount;
}

function dbInsertAddress(Address address) returns error? {
    mongodb:Collection col = check getCollection(ADDRESSES);
    check col->insertOne(address);
}

function dbFindAddresses(string customerId) returns Address[]|error {
    mongodb:Collection col = check getCollection(ADDRESSES);
    stream<Address, error?> results = check col->find({customerId: customerId}, {}, HIDE_MONGO_ID, Address);
    return from Address a in results
        select a;
}

function dbFindAddress(string customerId, string addressId) returns Address|error? {
    mongodb:Collection col = check getCollection(ADDRESSES);
    return col->findOne({id: addressId, customerId: customerId}, {}, HIDE_MONGO_ID, Address);
}

function dbUpdateAddress(string customerId, string addressId, map<json> changes) returns int|error {
    mongodb:Collection col = check getCollection(ADDRESSES);
    mongodb:UpdateResult result = check col->updateOne({id: addressId, customerId: customerId}, {set: changes});
    return result.matchedCount;
}

function dbClearDefaultAddress(string customerId) returns error? {
    mongodb:Collection col = check getCollection(ADDRESSES);
    _ = check col->updateMany({customerId: customerId}, {set: {isDefault: false}});
}

function dbDeleteAddress(string customerId, string addressId) returns int|error {
    mongodb:Collection col = check getCollection(ADDRESSES);
    mongodb:DeleteResult result = check col->deleteOne({id: addressId, customerId: customerId});
    return result.deletedCount;
}

function dbFindOrdersByCustomer(string customerId) returns Order[]|error {
    mongodb:Collection col = check getCollection(ORDERS);
    stream<Order, error?> results = check col->find(
        {customerId: customerId},
        {sort: {createdAt: -1}},
        HIDE_MONGO_ID,
        Order
    );
    return from Order o in results
        select o;
}

function dbInsertOrder(Order 'order) returns error? {
    mongodb:Collection col = check getCollection(ORDERS);
    check col->insertOne('order);
}
