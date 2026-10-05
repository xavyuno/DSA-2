type OrderCreatedEvent record {|
    string orderId;
    string customerId;
    string restaurantId;
    string[] items;
    string status;
|};

type RestaurantStats record {|
    string restaurantId;
    int orderCount;
|};

type RestaurantReport record {|
    string restaurantId;
    int orderCount;
|};

type RestaurantReportList record {|
    RestaurantReport[] reports;
    int count;
|};