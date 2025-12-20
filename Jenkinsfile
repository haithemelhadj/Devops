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



        stage('SonarQube Analysis') {
            steps {
                withCredentials([string(credentialsId: 'jenkins-sonar-token', variable: 'SONAR_TOKEN')]) {
                    sh  '''
                    mvn sonar:sonar \
                      -Dsonar.projectKey=devops-app \
                      -Dsonar.host.url=http://localhost:9000 \
                      -Dsonar.login=$SONAR_TOKEN
                     '''
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
                        credentialsId: 'dockerhub-creds',
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

        //-------
        //-----
        stage('Deploy to Kubernetes') {
    steps {
        script {
            // Start Minikube in Docker inside the pipeline workspace
            sh '''
            export MINIKUBE_HOME=$WORKSPACE/.minikube
            minikube start --driver=docker --kubernetes-version=v1.34.0 --profile=jenkins-minikube
            export KUBECONFIG=$MINIKUBE_HOME/profiles/jenkins-minikube/kubeconfig
            kubectl apply -f k8s/deployment.yaml
            kubectl apply -f k8s/service.yaml
            '''
            
            // Optional: get service URL
            sh 'kubectl get svc devops-app-service -o jsonpath="{.status.loadBalancer.ingress[0].ip}" || minikube service devops-app-service --url'
        }
    }
}
//-----


    }
}
