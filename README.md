# Alex's Restaurant Service & Inventory

This folder is my part of our Distributed Food Delivery Platform project. I am doing **Role 3: Restaurant Service & Inventory**.

My service handles the restaurant side of the platform: restaurant details, opening hours, menus and stock. It also listens to the `orders.created` Kafka topic so that stock can be reduced when the Order Service creates an order.

I have kept this part intentionally simple. I would rather have code that I can understand, explain and defend properly than add unnecessary complexity.

## How this fits with Person 1's Order Service

I updated my service to use the Order Service that is already being built by Person 1 instead of inventing a different order format.

Person 1's order currently looks like this:

```json
{
  "orderId": "ORD-1001",
  "customerId": "CUST-001",
  "restaurantId": "REST-001",
  "items": ["BURGER-01", "BURGER-01", "CHIPS-01"],
  "status": "CREATED"
}
```

The important part for me is `items`.

Person 1 used a simple `string[]`, so I also kept it simple. Each string is the **item ID** from my menu and represents one unit of that item.

For example:

```text
["BURGER-01", "CHIPS-01"]
```

means one burger and one chips.

If somebody orders two burgers, the order can contain the same item ID twice:

```text
["BURGER-01", "BURGER-01"]
```

My service will therefore reduce the burger stock by 2.

This means Person 1 does **not** have to change the structure of the Order Service just to work with my service. We only need to agree that the strings inside `items` are menu item IDs.

Both services use Ballerina `2201.13.5`. Person 1's generated dependency file resolves `ballerinax/kafka` to `4.6.6`, so I use that same Kafka connector version here. This keeps the integration versions aligned.

## What my service does

My part currently lets me:

- create a restaurant;
- view a restaurant;
- change its opening and closing times;
- add menu items;
- view the menu;
- remove menu items;
- view current stock;
- manually restock an item;
- listen to `orders.created` from Kafka; and
- automatically reduce stock when an order comes in.

The restaurant and menu data are currently stored in Ballerina tables in memory. That keeps my part easy to test while the group is putting everything together. The Database Lead can replace the temporary tables with MongoDB later.

## Files in my folder

```text
restaurant_service/
├── main.bal
├── Ballerina.toml
├── README.md
├── Bonus_UI.html
├── sample-order.json
└── .gitignore
```

`main.bal` is the actual Restaurant Service.

`Bonus_UI.html` is only a small optional interface I made to make the demo easier. The REST API is still the actual service.

`sample-order.json` shows the order format I expect from Person 1.

## Running my service

Kafka needs to be running on the normal local Kafka address:

```text
localhost:9092
```

From inside my folder I run:

```bash
bal build
```

If that succeeds:

```bash
bal run
```

My REST API runs on:

```text
http://localhost:8083/restaurant
```

The Order Service is on port `8081`, so the two services do not clash.

## Testing the REST API

I do not edit `main.bal` every time I want to add a restaurant or change stock. Those things are done through the REST API while the program is running.

### Check that my service is alive

```bash
curl http://localhost:8083/restaurant/health
```

Expected result:

```text
restaurant-service is running
```

### Create a restaurant

```bash
curl -X POST http://localhost:8083/restaurant/restaurants \
  -H "Content-Type: application/json" \
  -d '{
    "restaurantId":"REST-001",
    "name":"Campus Kitchen",
    "openingTime":"08:00",
    "closingTime":"22:00"
  }'
```

### View the restaurant

```bash
curl http://localhost:8083/restaurant/restaurants/REST-001
```

### Add a burger

```bash
curl -X POST http://localhost:8083/restaurant/restaurants/REST-001/menu \
  -H "Content-Type: application/json" \
  -d '{
    "itemId":"BURGER-01",
    "name":"Classic Burger",
    "price":75.00,
    "stock":20
  }'
```

### Add chips

```bash
curl -X POST http://localhost:8083/restaurant/restaurants/REST-001/menu \
  -H "Content-Type: application/json" \
  -d '{
    "itemId":"CHIPS-01",
    "name":"Chips",
    "price":30.00,
    "stock":30
  }'
```

### View the menu

```bash
curl http://localhost:8083/restaurant/restaurants/REST-001/menu
```

### View the inventory

```bash
curl http://localhost:8083/restaurant/restaurants/REST-001/inventory
```

### Restock the burgers to 50

```bash
curl -X PUT http://localhost:8083/restaurant/restaurants/REST-001/inventory/BURGER-01 \
  -H "Content-Type: application/json" \
  -d '{"stock":50}'
```

### Change opening hours

```bash
curl -X PUT http://localhost:8083/restaurant/restaurants/REST-001/hours \
  -H "Content-Type: application/json" \
  -d '{"openingTime":"09:00","closingTime":"23:00"}'
```

### Remove an item

```bash
curl -X DELETE http://localhost:8083/restaurant/restaurants/REST-001/menu/CHIPS-01
```

## Testing my service together with Person 1's Order Service

This is the test I actually care about for the distributed-system part.

First I make sure Kafka is running.

Then I run Person 1's Order Service on port `8081` and my Restaurant Service on port `8083`.

Before placing an order, I can check my stock:

```bash
curl http://localhost:8083/restaurant/restaurants/REST-001/inventory
```

Then I send an order to Person 1's service:

```bash
curl -X POST http://localhost:8081/orders \
  -H "Content-Type: application/json" \
  -d '{
    "orderId":"ORD-1001",
    "customerId":"CUST-001",
    "restaurantId":"REST-001",
    "items":["BURGER-01","BURGER-01","CHIPS-01"],
    "status":"CREATED"
  }'
```

Person 1's service sets the status to `CREATED` and publishes the order to Kafka on:

```text
orders.created
```

My service is subscribed to that topic. It receives the order and reads the item IDs.

If the stock started as:

```text
BURGER-01 = 20
CHIPS-01  = 30
```

then after that order I expect:

```text
BURGER-01 = 18
CHIPS-01  = 29
```

I can check it again with:

```bash
curl http://localhost:8083/restaurant/restaurants/REST-001/inventory
```

That is the main integration between Person 1's work and mine.

## Bonus UI

I also made a small file called `Bonus_UI.html`.

This is not needed for the Restaurant Service to work. It is just a simple interface so I can click buttons instead of typing every curl command during a demo.

To use it, I first run my Ballerina service:

```bash
bal run
```

Then in another terminal, from the same folder:

```bash
python3 -m http.server 3000
```

Then I open:

```text
http://localhost:3000/Bonus_UI.html
```

The Ballerina service contains a small CORS configuration so that this local page is allowed to call the API on port `8083`.

## One thing to remember about the database

Right now the data is in memory. If I stop `bal run`, the restaurants and menu items I created disappear.

That is fine for testing my logic, but before the final system is finished we should connect the service to the group's database design so the information survives a restart.

## How I would explain my part in the presentation

> My part is the Restaurant and Inventory Service. It manages restaurant details, opening hours, menus and stock through a REST API. The service also subscribes to the `orders.created` Kafka topic. I matched my Kafka consumer to the Order Service that the group is already using. Their order stores item IDs in a string array, so whenever I receive an item ID I reduce that item's stock by one. This keeps the integration simple and means the two services can communicate without us adding unnecessary structures.
