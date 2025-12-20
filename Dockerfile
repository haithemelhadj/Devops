FROM eclipse-temurin:17-jdk

WORKDIR /app

COPY target/*.jar app.jar

EXPOSE 8089

ENTRYPOINT ["java", "-jar", "app.jar"]

minikube kubectl --profile=jenkins-minikube -- get pods -o wide
minikube kubectl --profile=jenkins-minikube -- describe pod -l app=devops-app
minikube kubectl --profile=jenkins-minikube -- logs -l app=devops-app
