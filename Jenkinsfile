pipeline {
    agent any

    tools {
        maven 'maven-3'
        jdk 'Java 17'
    }

    environment {
        DOCKER_IMAGE = "haithemelhadj/devops-app"
        SONARQUBE_SERVER = "sonarqube-server"
    }

    stages {

        stage('Clone Repo') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-token',
                    url: 'https://github.com/haithemelhadj/Devops.git'
            }
        }

        stage('Build with Maven') {
            steps {
                sh 'mvn clean package'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${DOCKER_IMAGE}:latest ."
            }
        }

        stage('Run Container') {
            steps {
                sh """
                docker rm -f devops_container || true
                docker run -d --name devops_container -p 8081:8080 ${DOCKER_IMAGE}:latest
                """
            }
        }
    }
}
