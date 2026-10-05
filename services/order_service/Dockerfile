# Change 2201.10.0 to the version printed by `bal version` on your laptop
FROM ballerina/ballerina:2201.10.0 AS build
USER root
WORKDIR /app
COPY . .
RUN bal build

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/target/bin/*.jar app.jar
COPY Config.toml /app/Config.toml
ENV BAL_CONFIG_FILES=/app/Config.toml
EXPOSE 8081 9797
CMD ["java", "-jar", "app.jar"]
