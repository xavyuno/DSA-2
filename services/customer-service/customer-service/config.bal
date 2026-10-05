// ===========================================================================
// config.bal  -  All settings for the Customer Service live here.
//
// A `configurable` variable is a value that can be changed WITHOUT editing
// the code. The value after `=` is the default. You can override it with:
//   1. A Config.toml file next to Ballerina.toml, e.g.  servicePort = 9090
//   2. An environment variable:  BAL_CONFIG_VAR_SERVICEPORT=9090
//      (this is what docker-compose.yml uses)
// ===========================================================================

// The port the REST API listens on.
configurable int servicePort = 8081;

// Connection string for MongoDB.
// Locally: mongodb://localhost:27017   In Docker: mongodb://mongodb:27017
configurable string mongoUrl = "mongodb://localhost:27017";

// Name of the MongoDB database shared by the food delivery services.
configurable string mongoDatabase = "food_delivery";
