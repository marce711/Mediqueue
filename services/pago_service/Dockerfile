FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY payment-service/pom.xml ./payment-service/pom.xml
COPY payment-service/src ./payment-service/src
WORKDIR /workspace/payment-service
RUN mvn -B -DskipTests clean package

FROM eclipse-temurin:21-jre
WORKDIR /app
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /workspace/payment-service/target/*.jar app.jar
EXPOSE 8084
HEALTHCHECK --interval=15s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8084/actuator/health || exit 1
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
