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
                    sh '''
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
                        docker push ${DOCKER_IMAGE}:latest
                        '''
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

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    // Install minikube & kubectl dynamically inside Jenkins pipeline
                    sh '''
                    # Use a local workspace for minikube
                    export MINIKUBE_HOME=$WORKSPACE/.minikube
                    export PATH=$WORKSPACE/.minikube/bin:$PATH

                    # Install kubectl (if not installed)
                    if [ ! -f $WORKSPACE/.minikube/bin/kubectl ]; then
                        mkdir -p $WORKSPACE/.minikube/bin
                        curl -Lo $WORKSPACE/.minikube/bin/kubectl https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
                        chmod +x $WORKSPACE/.minikube/bin/kubectl
                    fi

                    # Install minikube (if not installed)
                    if [ ! -f $WORKSPACE/.minikube/bin/minikube ]; then
                        curl -Lo $WORKSPACE/.minikube/bin/minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
                        chmod +x $WORKSPACE/.minikube/bin/minikube
                    fi

                    # Start minikube
                    $WORKSPACE/.minikube/bin/minikube start --driver=docker --kubernetes-version=v1.34.0 --profile=jenkins-minikube

                    # Set kubeconfig
                    export KUBECONFIG=$MINIKUBE_HOME/profiles/jenkins-minikube/kubeconfig

                    # Deploy app
                    $WORKSPACE/.minikube/bin/minikube kubectl -- apply -f k8s/deployment.yaml
                    $WORKSPACE/.minikube/bin/minikube kubectl -- apply -f k8s/service.yaml

                    # Optional: get service URL
                    $WORKSPACE/.minikube/bin/minikube service devops-app-service --url
                    '''
                }
            }
        }
    }
}
