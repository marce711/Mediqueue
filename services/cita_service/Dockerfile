FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY citaservice/pom.xml ./citaservice/pom.xml
COPY citaservice/src ./citaservice/src
WORKDIR /workspace/citaservice
RUN mvn -B -DskipTests clean package

FROM eclipse-temurin:21-jre
WORKDIR /app
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /workspace/citaservice/target/*.jar app.jar
EXPOSE 8081
HEALTHCHECK --interval=15s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8081/actuator/health || exit 1
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
