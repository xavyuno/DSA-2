// ===========================================================================
// db.bal  -  Everything that talks to MongoDB lives in this file.
//
// MongoDB stores "documents" (JSON-like objects) inside "collections"
// (like tables). We use three collections:
//   customers  -> one document per customer
//   addresses  -> one document per delivery address (has a customerId field)
//   orders     -> written by the Order Service, we only read it
//
// Every function returns either a value OR an `error`.
// `check` means: "if this failed, stop and return the error to my caller".
// ===========================================================================

import ballerinax/mongodb;

// Collection names kept in one place so we never mistype them.
const string CUSTOMERS = "customers";
const string ADDRESSES = "addresses";
const string ORDERS = "orders";

// MongoDB stores its own internal "_id" field on every document.
// This "projection" tells MongoDB NOT to send _id back, because we use our
// own "id" field instead.
final map<json> & readonly HIDE_MONGO_ID = {"_id": 0};

// The MongoDB client is created ONCE when the service starts.
// `final` = it never changes afterwards.
final mongodb:Client mongoClient = check new ({connection: mongoUrl});

// Small helper: get a collection object by name from our database.
function getCollection(string name) returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase(mongoDatabase);
    return db->getCollection(name);
}

// ---------------------------------------------------------------------------
// CUSTOMER operations
// ---------------------------------------------------------------------------

// INSERT a new customer document.
function dbInsertCustomer(Customer customer) returns error? {
    mongodb:Collection col = check getCollection(CUSTOMERS);
    check col->insertOne(customer);
}

// FIND one customer by id. Returns () (nil = "nothing") if not found.
function dbFindCustomerById(string id) returns Customer|error? {
    mongodb:Collection col = check getCollection(CUSTOMERS);
    return col->findOne({id: id}, {}, HIDE_MONGO_ID, Customer);
}

// FIND one customer by email (used to stop duplicate registrations).
function dbFindCustomerByEmail(string email) returns Customer|error? {
    mongodb:Collection col = check getCollection(CUSTOMERS);
    return col->findOne({email: email}, {}, HIDE_MONGO_ID, Customer);
}

// UPDATE the given fields of a customer. `changes` holds only the fields
// to change, e.g. {"name": "New Name"}. Returns how many documents matched.
function dbUpdateCustomer(string id, map<json> changes) returns int|error {
    mongodb:Collection col = check getCollection(CUSTOMERS);
    mongodb:UpdateResult result = check col->updateOne({id: id}, {set: changes});
    return result.matchedCount;
}

// DELETE a customer AND all of their addresses. Returns how many customers
// were deleted (0 = the customer did not exist).
function dbDeleteCustomer(string id) returns int|error {
    mongodb:Collection customers = check getCollection(CUSTOMERS);
    mongodb:DeleteResult result = check customers->deleteOne({id: id});

    // Clean up the customer's addresses too, so we leave no orphans.
    mongodb:Collection addresses = check getCollection(ADDRESSES);
    _ = check addresses->deleteMany({customerId: id});
    return result.deletedCount;
}

// ---------------------------------------------------------------------------
// ADDRESS operations
// ---------------------------------------------------------------------------

// INSERT a new address document.
function dbInsertAddress(Address address) returns error? {
    mongodb:Collection col = check getCollection(ADDRESSES);
    check col->insertOne(address);
}

// FIND all addresses for one customer.
function dbFindAddresses(string customerId) returns Address[]|error {
    mongodb:Collection col = check getCollection(ADDRESSES);
    stream<Address, error?> results = check col->find({customerId: customerId}, {}, HIDE_MONGO_ID, Address);
    // Turn the stream (a "flow" of results) into a normal array.
    return from Address a in results
        select a;
}

// FIND one specific address of a customer.
function dbFindAddress(string customerId, string addressId) returns Address|error? {
    mongodb:Collection col = check getCollection(ADDRESSES);
    return col->findOne({id: addressId, customerId: customerId}, {}, HIDE_MONGO_ID, Address);
}

// UPDATE fields of one address. Returns how many documents matched.
function dbUpdateAddress(string customerId, string addressId, map<json> changes) returns int|error {
    mongodb:Collection col = check getCollection(ADDRESSES);
    mongodb:UpdateResult result = check col->updateOne({id: addressId, customerId: customerId}, {set: changes});
    return result.matchedCount;
}

// Make every address of this customer NOT default (used before we mark a
// new one as the default, so there is only ever ONE default address).
function dbClearDefaultAddress(string customerId) returns error? {
    mongodb:Collection col = check getCollection(ADDRESSES);
    _ = check col->updateMany({customerId: customerId}, {set: {isDefault: false}});
}

// DELETE one address. Returns how many were deleted.
function dbDeleteAddress(string customerId, string addressId) returns int|error {
    mongodb:Collection col = check getCollection(ADDRESSES);
    mongodb:DeleteResult result = check col->deleteOne({id: addressId, customerId: customerId});
    return result.deletedCount;
}

// ---------------------------------------------------------------------------
// ORDER HISTORY operations
// ---------------------------------------------------------------------------

// FIND all orders of a customer, newest first.
function dbFindOrdersByCustomer(string customerId) returns Order[]|error {
    mongodb:Collection col = check getCollection(ORDERS);
    stream<Order, error?> results = check col->find(
        {customerId: customerId},
        {sort: {createdAt: -1}},   // -1 = descending (newest first)
        HIDE_MONGO_ID,
        Order
    );
    return from Order o in results
        select o;
}

// INSERT an order (only used by the testing helper endpoint).
function dbInsertOrder(Order 'order) returns error? {
    mongodb:Collection col = check getCollection(ORDERS);
    check col->insertOne('order);
}
