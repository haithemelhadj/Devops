pipeline {
    agent any

    tools {
        maven 'maven-3'
        jdk 'Java 17'
    }

    environment {
        DOCKER_IMAGE = "haithemelhadj/devops-app"
        SONARQUBE_SERVER = "sonarqube-server"   // Name in Jenkins config
    }

    stages {

        stage('Clone Repository') {
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

        stage('Run SonarQube Analysis') {
            steps {
                withSonarQubeEnv("${SONARQUBE_SERVER}") {
                    sh '''
                    mvn sonar:sonar \
                    -Dsonar.projectKey=devops-project \
                    -Dsonar.host.url=http://localhost:9000 \
                    -Dsonar.login=YOUR_SONAR_TOKEN
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $DOCKER_IMA_
