type PaymentRequest record {|
    string orderId;
    string customerId;
    decimal amount;
    string paymentMethod;
|};

type Payment record {|
    string paymentId;
    string orderId;
    string customerId;
    decimal amount;
    string paymentMethod;
    string status;
    string transactionRef;
    string createdAt;
|};

type PaymentResponse record {|
    string paymentId;
    string status;
    string transactionRef;
|};

type PaymentEvent record {|
    string paymentId;
    string orderId;
    string customerId;
    decimal amount;
    string status;
    string timestamp;
|};
