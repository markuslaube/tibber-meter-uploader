FROM maven:3-openjdk-17 as builder

ADD . /src

WORKDIR /src

RUN mvn -B package && chmod 0755 /src/target/tibber-meter-uploader-1.0.0-SNAPSHOT.jar

FROM alpine:latest

COPY --from=builder /src/target/tibber-meter-uploader-1.0.0-SNAPSHOT.jar /tibber-meter-uploader-1.0.0-SNAPSHOT.jar
COPY read_AIotE_from_influxd2.sh /read_AIotE_from_influxd2.sh

RUN apk add --no-cache openjdk18 jq bash curl coreutils

CMD /tibber-meter-uploader-1.0.0-SNAPSHOT.jar
