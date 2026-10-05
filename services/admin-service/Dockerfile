FROM ballerina/ballerina:latest
WORKDIR /home/ballerina
COPY . .
RUN bal build
EXPOSE 8087
CMD ["bal", "run"]