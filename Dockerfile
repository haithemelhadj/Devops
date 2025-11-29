# Base image
FROM ubuntu:20.04

# Install Java (needed for Maven builds)
RUN apt-get update && apt-get install -y openjdk-17-jdk maven git curl

# Set working directory
WORKDIR /app

# Copy repo contents into container
COPY . /app

# Default command
CMD ["bash"]
