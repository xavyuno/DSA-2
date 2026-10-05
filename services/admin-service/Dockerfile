FROM ballerina/ballerina:2201.13.0
USER root
WORKDIR /home/ballerina
COPY . .
RUN mkdir -p /home/ballerina/target && chmod -R 777 /home/ballerina/target
USER ballerina
RUN bal build
EXPOSE 8087
CMD ["bal", "run"]