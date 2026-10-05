import ballerina/http;
import ballerina/io;

public function main() returns error? {
    io:println("Admin Service starting...");
    check runConsumer();
}

service /admin on new http:Listener(adminPort) {

    resource function get reports/restaurants() returns RestaurantReportList|error {
        RestaurantStats[] stats = check getAllRestaurantStats();

        RestaurantReport[] reports = [];
        foreach RestaurantStats s in stats {
            RestaurantReport r = {
                restaurantId: s.restaurantId,
                orderCount: s.orderCount
            };
            reports.push(r);
        }

        RestaurantReportList result = {
            reports: reports,
            count: reports.length()
        };
        return result;
    }
}