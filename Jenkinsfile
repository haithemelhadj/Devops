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

#        stage('Push Docker Image') {
#            steps {
#                script {
#                    withCredentials([usernamePassword(
#                        credentialsId: 'dockerhub-creds',
#                        usernameVariable: 'DOCKER_USERNAME',
#                        passwordVariable: 'DOCKER_PASSWORD'
#                    )]) {
#                        sh '''
#                        echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin
#                        docker push ${DOCKER_IMAGE}:latest
#                        '''
#                    }
#                }
#            }
#        }

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
                    sh '''
                    export MINIKUBE_HOME=$WORKSPACE/.minikube
                    export PATH=$WORKSPACE/.minikube/bin:$PATH

                    # Start Minikube with a dedicated profile
                    $MINIKUBE_HOME/bin/minikube start --driver=docker --kubernetes-version=v1.34.0 --profile=jenkins-minikube --wait=all

                    # Use minikube kubectl with the same profile
                    $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- apply -f k8s/deployment.yaml
                    $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- apply -f k8s/service.yaml

                    # Wait for deployment to be ready
                    $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                        rollout status deployment/devops-app --timeout=180s

                    # Wait for pod readiness
                    $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                        wait --for=condition=ready pod -l app=devops-app --timeout=180s


                    # Optional: get service URL
                    $MINIKUBE_HOME/bin/minikube service devops-app-service --profile=jenkins-minikube --url
                    '''
                }
            }
        }
      stage('Deploy Monitoring (Prometheus + Grafana)') {
    steps {
        sh '''
        set -e

        export MINIKUBE_HOME=$WORKSPACE/.minikube
        export HELM_HOME=$WORKSPACE/.helm
        export PATH=$MINIKUBE_HOME/bin:$HELM_HOME/bin:$PATH

        mkdir -p $HELM_HOME/bin

        # Install Helm locally (no sudo)
        if [ ! -f "$HELM_HOME/bin/helm" ]; then
          curl -sSL https://get.helm.sh/helm-v3.15.4-linux-amd64.tar.gz -o helm.tar.gz
          tar -xzf helm.tar.gz
          mv linux-amd64/helm $HELM_HOME/bin/helm
          chmod +x $HELM_HOME/bin/helm
        fi

        # Start Minikube (idempotent)
        minikube start --driver=docker --profile=jenkins-minikube --wait=all

        # Create namespace safely
        minikube kubectl --profile=jenkins-minikube -- \
          create namespace monitoring --dry-run=client -o yaml | \
        minikube kubectl --profile=jenkins-minikube -- apply -f -

        # Add Helm repos
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo add grafana https://grafana.github.io/helm-charts
        helm repo update

        # Install Prometheus
        helm upgrade --install prometheus prometheus-community/prometheus \
          --namespace monitoring \
          --set server.service.type=NodePort \
          --set server.service.nodePort=30090

        # Install Grafana
        helm upgrade --install grafana grafana/grafana \
          --namespace monitoring \
          --set service.type=NodePort \
          --set service.nodePort=30030 \
          --set adminPassword=admin

        # Wait for Grafana
        minikube kubectl --profile=jenkins-minikube -- \
          rollout status deployment/grafana -n monitoring --timeout=180s

        echo "Prometheus URL:"
        minikube service prometheus-server -n monitoring --profile=jenkins-minikube --url

        echo "Grafana URL:"
        minikube service grafana -n monitoring --profile=jenkins-minikube --url
        '''
    }
}


    }
}
