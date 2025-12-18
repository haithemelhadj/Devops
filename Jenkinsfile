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
        sh 'mvn clean package -DskipTests'
    }
}


        stage('Run Tests') {
            steps {
                sh 'mvn test'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withCredentials([string(credentialsId: 'jenkins-sonar', variable: 'SONAR_TOKEN')]) {
                    sh """
                    mvn sonar:sonar \
                      -Dsonar.projectKey=devops-app \
                      -Dsonar.host.url=http://your-sonarqube:9000 \
                      -Dsonar.login=$SONAR_TOKEN
                    """
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${DOCKER_IMAGE}:latest ."
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: 'docker-hub-credentials',
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )]) {
                        sh '''
                        echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin
                        docker push ''' + "${DOCKER_IMAGE}:latest"
                    }
                }
            }
        }

        stage('Run Container') {
            steps {
                sh """
                docker rm -f devops_container || true
                docker run -d \
                    --name devops_container \
                    --network host \
                    ${DOCKER_IMAGE}:latest
                """
            }
        }
    }
}
