# Use multi-stage build to reduce image size
FROM eclipse-temurin:17-jdk-alpine AS builder

WORKDIR /app

# Copy the JAR file
COPY target/*.jar app.jar

# Extract layers for better caching
RUN java -Djarmode=layertools -jar app.jar extract

# Final stage - use JRE instead of JDK
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Copy layers from builder
COPY --from=builder app/dependencies/ ./
COPY --from=builder app/spring-boot-loader/ ./
COPY --from=builder app/snapshot-dependencies/ ./
COPY --from=builder app/application/ ./

EXPOSE 8089

# Use shell form to allow environment variable expansion
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
