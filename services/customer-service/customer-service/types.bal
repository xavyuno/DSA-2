// ===========================================================================
// types.bal  -  The "shapes" of the data this service works with.
//
// A `record` in Ballerina is like a class/struct with fields.
// `?` after a field name means the field is OPTIONAL.
// `record {| ... |}` (with the bars) is a CLOSED record: no extra fields allowed.
// ===========================================================================

// ---------------------------------------------------------------------------
// CUSTOMER
// ---------------------------------------------------------------------------

// What the client sends when registering a new customer (POST /customers).
// The plain password is NEVER stored - we save only a SHA-256 hash of it.
public type CustomerCreateRequest record {|
    string name;
    string email;
    string phone;
    string password;
|};

// What the client sends when updating a profile (PUT /customers/{id}).
// Every field is optional, so the client can update just one thing.
public type CustomerUpdateRequest record {|
    string name?;
    string email?;
    string phone?;
    string password?;
|};

// A customer exactly as it is stored in MongoDB ("customers" collection).
public type Customer record {|
    string id;              // our own unique id (a UUID)
    string name;
    string email;
    string phone;
    string passwordHash;    // SHA-256 hash of the password (hex text)
    string createdAt;       // date/time in UTC, e.g. 2026-10-05T10:00:00Z
    string updatedAt;
|};

// What we send BACK to the client. Notice: NO passwordHash (keep it secret!).
public type CustomerResponse record {|
    string id;
    string name;
    string email;
    string phone;
    string createdAt;
    string updatedAt;
|};

// ---------------------------------------------------------------------------
// ADDRESS  (a customer can have many delivery addresses)
// ---------------------------------------------------------------------------

// Body for POST /customers/{id}/addresses
public type AddressCreateRequest record {|
    string street;
    string city;
    string country;
    boolean isDefault = false;   // default value if the client leaves it out
|};

// Body for PUT /customers/{id}/addresses/{addressId} (all optional)
public type AddressUpdateRequest record {|
    string street?;
    string city?;
    string country?;
    boolean isDefault?;
|};

// An address as stored in MongoDB ("addresses" collection).
public type Address record {|
    string id;
    string customerId;     // which customer this address belongs to
    string street;
    string city;
    string country;
    boolean isDefault;
    string createdAt;
|};

// ---------------------------------------------------------------------------
// ORDER HISTORY
// The Order Service (built by a teammate) writes orders into the shared
// "orders" collection. We only READ them to show a customer's history.
// ---------------------------------------------------------------------------

// One item inside an order.
public type OrderItem record {|
    string itemId;
    string name;
    int quantity;
    decimal price;
|};

// An order as stored in the "orders" collection.
// It is an OPEN record (no bars) so extra fields added by the Order Service
// will not break us.
public type Order record {
    string orderId;
    string customerId;
    string restaurantId?;
    OrderItem[] items?;
    decimal totalAmount;
    string status;          // e.g. CREATED, PAID, DELIVERED
    string createdAt;
};

// Body for POST /customers/{id}/orders (helper endpoint used for TESTING
// order history before the Order Service exists).
public type OrderCreateRequest record {|
    string orderId?;
    string restaurantId?;
    OrderItem[] items = [];
    decimal totalAmount;
    string status = "CREATED";
|};

// Response for GET /customers/{id}/orders
public type OrderHistory record {|
    string customerId;
    int totalOrders;
    Order[] orders;
|};

// ---------------------------------------------------------------------------
// GENERIC ERROR MESSAGE body returned to the client
// ---------------------------------------------------------------------------
public type ErrorBody record {|
    string message;
|};
