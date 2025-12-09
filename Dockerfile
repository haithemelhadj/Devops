# Minimal base image
FROM ubuntu:20.04

# Install only what's needed to run the app
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the Maven-built JAR from Jenkins workspace
COPY target/*.jar app.jar

# Expose the port your app runs on
EXPOSE 8089

# Run the app using Java installed on the host (we'll use host networking)
ENTRYPOINT ["bash", "-c", "java -jar app.jar"]
