pipeline {
    agent any

    tools {
        maven 'maven-3'
        jdk 'Java 17'
    }

    environment {
        DOCKER_IMAGE = "haithemelhadj/devops-app"
        SONARQUBE_SERVER = "sonarqube-server"
        MINIKUBE_HOME = "${WORKSPACE}/.minikube"
        HELM_HOME = "${WORKSPACE}/.helm"
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
                sh "docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} -t ${DOCKER_IMAGE}:latest ."
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
                        docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
                        docker push ${DOCKER_IMAGE}:latest
                        '''
                    }
                }
            }
        }

        stage('Run Container Locally') {
            steps {
                sh """
                docker rm -f devops_container || true
                docker run -d \
                    --name devops_container \
                    -p 8089:8089 \
                    ${DOCKER_IMAGE}:latest
                """
                sh 'sleep 10'
                sh 'docker ps | grep devops_container'
            }
        }

        stage('Setup Minikube') {
            steps {
                sh '''
                export PATH=$MINIKUBE_HOME/bin:$PATH
                
                # Install Minikube if not exists
                if [ ! -f "$MINIKUBE_HOME/bin/minikube" ]; then
                    mkdir -p $MINIKUBE_HOME/bin
                    curl -Lo $MINIKUBE_HOME/bin/minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
                    chmod +x $MINIKUBE_HOME/bin/minikube
                fi
                
                # Start Minikube with valid version
                $MINIKUBE_HOME/bin/minikube start \
                    --driver=docker \
                    --profile=jenkins-minikube \
                    --memory=4096 \
                    --cpus=2 \
                    --wait=all \
                    --wait-timeout=5m
                
                # Verify Minikube is running
                $MINIKUBE_HOME/bin/minikube status --profile=jenkins-minikube
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                export PATH=$MINIKUBE_HOME/bin:$PATH
                
                # Create namespace
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    create namespace devops --dry-run=client -o yaml | \
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- apply -f -
                
                # Apply deployment and service
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    apply -f k8s/deployment.yaml -n devops
                    
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    apply -f k8s/service.yaml -n devops
                
                # Wait for deployment
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    rollout status deployment/devops-app -n devops --timeout=300s
                
                # Wait for pods
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    wait --for=condition=ready pod -l app=devops-app -n devops --timeout=300s
                
                # Get pods status
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    get pods -n devops
                
                # Get service URL
                echo "Application URL:"
                $MINIKUBE_HOME/bin/minikube service devops-app-service -n devops --profile=jenkins-minikube --url
                '''
            }
        }

        stage('Deploy Monitoring') {
            steps {
                sh '''
                set -e
                export PATH=$MINIKUBE_HOME/bin:$HELM_HOME/bin:$PATH
                
                mkdir -p $HELM_HOME/bin
                
                # Install Helm if not exists
                if [ ! -f "$HELM_HOME/bin/helm" ]; then
                    curl -sSL https://get.helm.sh/helm-v3.15.4-linux-amd64.tar.gz -o helm.tar.gz
                    tar -xzf helm.tar.gz
                    mv linux-amd64/helm $HELM_HOME/bin/helm
                    chmod +x $HELM_HOME/bin/helm
                    rm -rf helm.tar.gz linux-amd64
                fi
                
                # Create monitoring namespace
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
                    --set server.service.nodePort=30090 \
                    --set alertmanager.enabled=false \
                    --set prometheus-pushgateway.enabled=false \
                    --wait \
                    --timeout=5m
                
                # Install Grafana
                helm upgrade --install grafana grafana/grafana \
                    --namespace monitoring \
                    --set service.type=NodePort \
                    --set service.nodePort=30030 \
                    --set adminPassword=admin \
                    --set persistence.enabled=false \
                    --wait \
                    --timeout=5m
                
                # Verify deployments
                minikube kubectl --profile=jenkins-minikube -- get pods -n monitoring
                
                # Get URLs
                echo "=== Monitoring URLs ==="
                echo "Prometheus:"
                minikube service prometheus-server -n monitoring --profile=jenkins-minikube --url
                echo ""
                echo "Grafana:"
                minikube service grafana -n monitoring --profile=jenkins-minikube --url
                echo "Grafana credentials: admin / admin"
                '''
            }
        }
    }

    post {
        always {
            sh '''
            # Cleanup
            docker rm -f devops_container || true
            '''
        }
        failure {
            sh '''
            export PATH=$MINIKUBE_HOME/bin:$PATH
            echo "=== Debugging Information ==="
            $MINIKUBE_HOME/bin/minikube logs --profile=jenkins-minikube || true
            $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- get pods -A || true
            '''
        }
    }
}
