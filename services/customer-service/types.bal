public type CustomerCreateRequest record {|
    string name;
    string email;
    string phone;
    string password;
|};

public type CustomerUpdateRequest record {|
    string name?;
    string email?;
    string phone?;
    string password?;
|};

public type Customer record {|
    string id;
    string name;
    string email;
    string phone;
    string passwordHash;
    string createdAt;
    string updatedAt;
|};

public type CustomerResponse record {|
    string id;
    string name;
    string email;
    string phone;
    string createdAt;
    string updatedAt;
|};

public type AddressCreateRequest record {|
    string street;
    string city;
    string country;
    boolean isDefault = false;
|};

public type AddressUpdateRequest record {|
    string street?;
    string city?;
    string country?;
    boolean isDefault?;
|};

public type Address record {|
    string id;
    string customerId;
    string street;
    string city;
    string country;
    boolean isDefault;
    string createdAt;
|};

public type OrderItem record {|
    string itemId;
    string name;
    int quantity;
    decimal price;
|};

public type Order record {
    string orderId;
    string customerId;
    string restaurantId?;
    OrderItem[] items?;
    decimal totalAmount;
    string status;
    string createdAt;
};

public type OrderCreateRequest record {|
    string orderId?;
    string restaurantId?;
    OrderItem[] items = [];
    decimal totalAmount;
    string status = "CREATED";
|};

public type OrderHistory record {|
    string customerId;
    int totalOrders;
    Order[] orders;
|};

public type ErrorBody record {|
    string message;
|};
