# Use OpenJDK 17 official image
FROM openjdk:17-jdk

# Set working directory
WORKDIR /app

# Copy Maven-built JAR (adjust if your build output is different)
COPY target/*.jar app.jar

# Expose port your app runs on
EXPOSE 8089

# Run the JAR
ENTRYPOINT ["java", "-jar", "app.jar"]
