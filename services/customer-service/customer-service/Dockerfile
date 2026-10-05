FROM ballerina/ballerina:2201.10.3 AS build
WORKDIR /home/ballerina/app
COPY --chown=ballerina:ballerina . .
RUN bal build

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /home/ballerina/app/target/bin/*.jar app.jar
CMD ["java", "-jar", "app.jar"]
