import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;

// In-memory store for payments (lost when the service restarts).
map<Payment> payments = {};

function nowUtc() returns string => time:utcToString(time:utcNow());

service /payments on new http:Listener(servicePort) {

    function init() {
        log:printInfo(string `Payment Service started on port ${servicePort}`);
    }

    resource function get health() returns map<string> {
        return {status: "UP", 'service: "payment-service"};
    }

    // POST /payments -> mock checkout (always succeeds), then publish the event.
    resource function post .(PaymentRequest req)
            returns http:Created|http:BadRequest|http:InternalServerError {

        if req.orderId.trim() == "" || req.customerId.trim() == "" {
            return <http:BadRequest>{body: {message: "orderId and customerId are required"}};
        }
        if req.amount <= 0d {
            return <http:BadRequest>{body: {message: "amount must be greater than 0"}};
        }
        if req.paymentMethod != "CARD" && req.paymentMethod != "CASH" && req.paymentMethod != "WALLET" {
            return <http:BadRequest>{body: {message: "paymentMethod must be CARD, CASH or WALLET"}};
        }

        string now = nowUtc();
        Payment payment = {
            paymentId: uuid:createType4AsString().substring(0, 8),
            orderId: req.orderId,
            customerId: req.customerId,
            amount: req.amount,
            paymentMethod: req.paymentMethod,
            status: "SUCCESS",
            transactionRef: "TXN-" + uuid:createType4AsString().substring(0, 8).toUpperAscii(),
            createdAt: now
        };
        payments[payment.paymentId] = payment;

        PaymentEvent event = {
            paymentId: payment.paymentId,
            orderId: payment.orderId,
            customerId: payment.customerId,
            amount: payment.amount,
            status: payment.status,
            timestamp: now
        };
        error? sent = publishPaymentCompleted(event);
        if sent is error {
            log:printError("Failed to publish payments.completed", sent);
            return <http:InternalServerError>{body: {message: "Payment saved but event failed: " + sent.message()}};
        }

        PaymentResponse response = {
            paymentId: payment.paymentId,
            status: payment.status,
            transactionRef: payment.transactionRef
        };
        return <http:Created>{body: response};
    }

    // GET /payments/{paymentId}
    resource function get [string paymentId]() returns Payment|http:NotFound {
        Payment? payment = payments[paymentId];
        if payment is () {
            return <http:NotFound>{body: {message: "Payment not found: " + paymentId}};
        }
        return payment;
    }
}
