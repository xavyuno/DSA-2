import ballerina/crypto;
import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;

function nowUtc() returns string => time:utcToString(time:utcNow());

function shortId() returns string => uuid:createType4AsString().substring(0, 8);

function hashPassword(string password) returns string =>
    crypto:hashSha256(password.toBytes()).toBase16();

function toResponse(Customer c) returns CustomerResponse => {
    id: c.id,
    name: c.name,
    email: c.email,
    phone: c.phone,
    createdAt: c.createdAt,
    updatedAt: c.updatedAt
};

function notFound(string message) returns http:NotFound => {body: {message}};

function badRequest(string message) returns http:BadRequest => {body: {message}};

function serverError(error e) returns http:InternalServerError {
    log:printError("Unexpected error", e);
    return {body: {message: "Something went wrong on the server: " + e.message()}};
}

service /customers on new http:Listener(servicePort) {

    function init() {
        log:printInfo(string `Customer Service started on port ${servicePort}`);
    }

    resource function get health() returns map<string> {
        return {status: "UP", 'service: "customer-service"};
    }

    resource function post .(CustomerCreateRequest req)
            returns http:Created|http:BadRequest|http:Conflict|http:InternalServerError {

        if req.name.trim() == "" || req.email.trim() == "" || req.password == "" {
            return badRequest("name, email and password are required");
        }
        if !req.email.includes("@") {
            return badRequest("email address is not valid");
        }

        Customer|error? existing = dbFindCustomerByEmail(req.email);
        if existing is error {
            return serverError(existing);
        }
        if existing is Customer {
            return <http:Conflict>{body: {message: "A customer with this email already exists"}};
        }

        string now = nowUtc();
        Customer customer = {
            id: shortId(),
            name: req.name,
            email: req.email,
            phone: req.phone,
            passwordHash: hashPassword(req.password),
            createdAt: now,
            updatedAt: now
        };
        error? saved = dbInsertCustomer(customer);
        if saved is error {
            return serverError(saved);
        }

        log:printInfo("Customer registered", customerId = customer.id);
        return <http:Created>{body: toResponse(customer)};
    }

    resource function get [string id]()
            returns CustomerResponse|http:NotFound|http:InternalServerError {
        Customer|error? customer = dbFindCustomerById(id);
        if customer is error {
            return serverError(customer);
        }
        if customer is () {
            return notFound("Customer not found: " + id);
        }
        return toResponse(customer);
    }

    resource function put [string id](CustomerUpdateRequest req)
            returns CustomerResponse|http:BadRequest|http:NotFound|http:InternalServerError {

        map<json> changes = {};
        string? name = req.name;
        if name is string {
            changes["name"] = name;
        }
        string? email = req.email;
        if email is string {
            if !email.includes("@") {
                return badRequest("email address is not valid");
            }
            changes["email"] = email;
        }
        string? phone = req.phone;
        if phone is string {
            changes["phone"] = phone;
        }
        string? password = req.password;
        if password is string {
            changes["passwordHash"] = hashPassword(password);
        }
        if changes.length() == 0 {
            return badRequest("Nothing to update - send at least one field");
        }
        changes["updatedAt"] = nowUtc();

        int|error matched = dbUpdateCustomer(id, changes);
        if matched is error {
            return serverError(matched);
        }
        if matched == 0 {
            return notFound("Customer not found: " + id);
        }

        Customer|error? updated = dbFindCustomerById(id);
        if updated is Customer {
            return toResponse(updated);
        }
        if updated is error {
            return serverError(updated);
        }
        return notFound("Customer not found: " + id);
    }

    resource function delete [string id]()
            returns http:Ok|http:NotFound|http:InternalServerError {
        int|error deleted = dbDeleteCustomer(id);
        if deleted is error {
            return serverError(deleted);
        }
        if deleted == 0 {
            return notFound("Customer not found: " + id);
        }
        log:printInfo("Customer deleted", customerId = id);
        return <http:Ok>{body: {message: "Customer deleted", id: id}};
    }

    resource function post [string id]/addresses(AddressCreateRequest req)
            returns http:Created|http:BadRequest|http:NotFound|http:InternalServerError {

        if req.street.trim() == "" || req.city.trim() == "" || req.country.trim() == "" {
            return badRequest("street, city and country are required");
        }

        Customer|error? customer = dbFindCustomerById(id);
        if customer is error {
            return serverError(customer);
        }
        if customer is () {
            return notFound("Customer not found: " + id);
        }

        Address[]|error current = dbFindAddresses(id);
        if current is error {
            return serverError(current);
        }
        boolean makeDefault = req.isDefault || current.length() == 0;
        if makeDefault {
            error? cleared = dbClearDefaultAddress(id);
            if cleared is error {
                return serverError(cleared);
            }
        }

        Address address = {
            id: shortId(),
            customerId: id,
            street: req.street,
            city: req.city,
            country: req.country,
            isDefault: makeDefault,
            createdAt: nowUtc()
        };
        error? saved = dbInsertAddress(address);
        if saved is error {
            return serverError(saved);
        }
        return <http:Created>{body: address};
    }

    resource function get [string id]/addresses()
            returns Address[]|http:NotFound|http:InternalServerError {
        Customer|error? customer = dbFindCustomerById(id);
        if customer is error {
            return serverError(customer);
        }
        if customer is () {
            return notFound("Customer not found: " + id);
        }
        Address[]|error addresses = dbFindAddresses(id);
        if addresses is error {
            return serverError(addresses);
        }
        return addresses;
    }

    resource function put [string id]/addresses/[string addressId](AddressUpdateRequest req)
            returns Address|http:BadRequest|http:NotFound|http:InternalServerError {

        map<json> changes = {};
        string? street = req.street;
        if street is string {
            changes["street"] = street;
        }
        string? city = req.city;
        if city is string {
            changes["city"] = city;
        }
        string? country = req.country;
        if country is string {
            changes["country"] = country;
        }
        boolean? isDefault = req.isDefault;
        if isDefault is boolean {
            changes["isDefault"] = isDefault;
        }
        if changes.length() == 0 {
            return badRequest("Nothing to update - send at least one field");
        }

        Address|error? existing = dbFindAddress(id, addressId);
        if existing is error {
            return serverError(existing);
        }
        if existing is () {
            return notFound("Address not found: " + addressId);
        }

        if isDefault == true {
            error? cleared = dbClearDefaultAddress(id);
            if cleared is error {
                return serverError(cleared);
            }
        }

        int|error matched = dbUpdateAddress(id, addressId, changes);
        if matched is error {
            return serverError(matched);
        }

        Address|error? updated = dbFindAddress(id, addressId);
        if updated is Address {
            return updated;
        }
        if updated is error {
            return serverError(updated);
        }
        return notFound("Address not found: " + addressId);
    }

    resource function delete [string id]/addresses/[string addressId]()
            returns http:Ok|http:NotFound|http:InternalServerError {
        int|error deleted = dbDeleteAddress(id, addressId);
        if deleted is error {
            return serverError(deleted);
        }
        if deleted == 0 {
            return notFound("Address not found: " + addressId);
        }
        return <http:Ok>{body: {message: "Address deleted", id: addressId}};
    }

    resource function get [string id]/orders()
            returns OrderHistory|http:NotFound|http:InternalServerError {
        Customer|error? customer = dbFindCustomerById(id);
        if customer is error {
            return serverError(customer);
        }
        if customer is () {
            return notFound("Customer not found: " + id);
        }
        Order[]|error orders = dbFindOrdersByCustomer(id);
        if orders is error {
            return serverError(orders);
        }
        return {customerId: id, totalOrders: orders.length(), orders: orders};
    }

    resource function post [string id]/orders(OrderCreateRequest req)
            returns http:Created|http:BadRequest|http:NotFound|http:InternalServerError {
        if req.totalAmount < 0d {
            return badRequest("totalAmount cannot be negative");
        }
        Customer|error? customer = dbFindCustomerById(id);
        if customer is error {
            return serverError(customer);
        }
        if customer is () {
            return notFound("Customer not found: " + id);
        }

        Order newOrder = {
            orderId: req.orderId ?: shortId(),
            customerId: id,
            items: req.items,
            totalAmount: req.totalAmount,
            status: req.status,
            createdAt: nowUtc()
        };
        string? restaurantId = req.restaurantId;
        if restaurantId is string {
            newOrder.restaurantId = restaurantId;
        }

        error? saved = dbInsertOrder(newOrder);
        if saved is error {
            return serverError(saved);
        }
        return <http:Created>{body: newOrder};
    }
}
