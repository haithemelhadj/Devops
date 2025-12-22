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

        stage('Cleanup Previous Run') {
            steps {
                sh '''
                # Stop and clean any previous Minikube instance
                export PATH=$MINIKUBE_HOME/bin:$PATH
                
                if [ -f "$MINIKUBE_HOME/bin/minikube" ]; then
                    echo "Cleaning up previous Minikube instance..."
                    $MINIKUBE_HOME/bin/minikube delete --profile=jenkins-minikube || true
                    
                    # Clean Minikube cache and configs
                    rm -rf $MINIKUBE_HOME/.kube || true
                    rm -rf $MINIKUBE_HOME/profiles/jenkins-minikube || true
                fi
                
                # Clean up old Docker containers
                docker rm -f devops_container || true
                
                echo "Cleanup completed"
                '''
            }
        }

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
                    # Ensure no Minikube interference
                    unset KUBECONFIG
                    
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
                sh """
#                export DOCKER_BUILDKIT=1
#                docker build \
#                  --cache-from ${DOCKER_IMAGE}:latest \
#                  -t ${DOCKER_IMAGE}:${BUILD_NUMBER} \
#                  -t ${DOCKER_IMAGE}:latest .
                """
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
#                        echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin
#                        docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
#                        docker push ${DOCKER_IMAGE}:latest
                        '''
                    }
                }
            }
        }

        stage('Setup Minikube') {
            steps {
                sh '''
                export PATH=$MINIKUBE_HOME/bin:$PATH
                
                # Install Minikube if not exists
                if [ ! -f "$MINIKUBE_HOME/bin/minikube" ]; then
                    echo "Installing Minikube..."
                    mkdir -p $MINIKUBE_HOME/bin
                    curl -Lo $MINIKUBE_HOME/bin/minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
                    chmod +x $MINIKUBE_HOME/bin/minikube
                else
                    echo "Minikube already installed"
                fi
                
                # Clean any corrupted Docker containers from previous runs
                echo "Cleaning Docker system..."
                docker system prune -f --volumes
                
                # Start fresh Minikube instance
                echo "Starting Minikube..."
                $MINIKUBE_HOME/bin/minikube start \
                    --driver=docker \
                    --profile=jenkins-minikube \
                    --memory=6144 \
                    --cpus=3 \
                    --disk-size=40g \
                    --delete-on-failure \
                    --wait=all \
                    --wait-timeout=10m
                
                # Verify Minikube is running
                echo "Verifying Minikube status..."
                $MINIKUBE_HOME/bin/minikube status --profile=jenkins-minikube
                
                # Test kubectl connectivity
                echo "Testing kubectl connectivity..."
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- get nodes
                
                echo "Minikube setup completed successfully"
                '''
            }
        }

        stage('Deploy MySQL to Kubernetes') {
            steps {
                sh '''
                export PATH=$MINIKUBE_HOME/bin:$PATH
                
                # Verify Minikube is still running
                if ! $MINIKUBE_HOME/bin/minikube status --profile=jenkins-minikube | grep -q "Running"; then
                    echo "ERROR: Minikube is not running!"
                    exit 1
                fi
                
                # Create namespace
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    create namespace devops --dry-run=client -o yaml | \
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- apply -f -
                
                echo "=== Deploying MySQL ==="
                
                # Apply MySQL deployment (PV, PVC, Secret, Deployment, Service)
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    apply -f k8s/mysql-deployment.yaml
                
                # Wait for PVC to be bound
                echo "Waiting for MySQL PVC to be bound..."
                timeout 120s bash -c 'until kubectl get pvc mysql-pvc -n devops -o jsonpath="{.status.phase}" | grep -q "Bound"; do echo "Waiting..."; sleep 5; done' || {
                    echo "PVC binding timeout"
                    $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- describe pvc mysql-pvc -n devops
                    exit 1
                }
                
                # Wait for MySQL deployment
                echo "Waiting for MySQL deployment to be ready..."
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    rollout status deployment/mysql -n devops --timeout=300s
                
                # Wait for MySQL pods to be ready
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    wait --for=condition=ready pod -l app=mysql -n devops --timeout=300s
                
                # Verify MySQL is running
                echo "=== MySQL Status ==="
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    get pods,pvc,svc -l app=mysql -n devops
                
                # Test MySQL connection
                echo "Testing MySQL connection..."
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    exec -n devops deployment/mysql -- \
                    mysqladmin ping -h localhost -u root -prootpassword
                
                echo "MySQL deployment completed successfully!"
                '''
            }
        }

        stage('Deploy Spring Boot to Kubernetes') {
            steps {
                sh '''
                export PATH=$MINIKUBE_HOME/bin:$PATH
                
                echo "=== Deploying Spring Boot Application ==="
                
                # Apply Spring Boot deployment (PV, PVC, ConfigMap, Secret, Deployment, Service)
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    apply -f k8s/spring-deployment.yaml
                
                # Wait for PVC to be bound
                echo "Waiting for Spring Boot PVC to be bound..."
                timeout 120s bash -c 'until kubectl get pvc spring-logs-pvc -n devops -o jsonpath="{.status.phase}" | grep -q "Bound"; do echo "Waiting..."; sleep 5; done' || {
                    echo "PVC binding timeout"
                    $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- describe pvc spring-logs-pvc -n devops
                }
                
               
                # Wait for pods to be ready
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    wait --for=condition=ready pod -l app=devops-app -n devops --timeout=300s
                
                # Get all resources
                echo "=== Application Status ==="
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    get all,pvc,configmap,secret -n devops
                
                # Get application URL
                echo "=== Application URL ==="
                APP_URL=$($MINIKUBE_HOME/bin/minikube service devops-app-service -n devops --profile=jenkins-minikube --url)
                echo "Application accessible at: $APP_URL"
                
                # Test health endpoint
                echo "=== Testing Application Health ==="
                sleep 15
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    exec -n devops deployment/devops-app -- \
                    curl -s http://localhost:8089/actuator/health || echo "Health check will be available once app fully starts"
                
                echo "Spring Boot deployment completed successfully!"
                '''
            }
        }

        stage('Deploy Monitoring') {
            steps {
                sh '''
                set -e
                export PATH=$MINIKUBE_HOME/bin:$HELM_HOME/bin:$PATH
                
                mkdir -p $HELM_HOME/bin
                
                echo "=== Installing Helm ==="
                # Install Helm if not exists
                if [ ! -f "$HELM_HOME/bin/helm" ]; then
                    curl -sSL https://get.helm.sh/helm-v3.15.4-linux-amd64.tar.gz -o helm.tar.gz
                    tar -xzf helm.tar.gz
                    mv linux-amd64/helm $HELM_HOME/bin/helm
                    chmod +x $HELM_HOME/bin/helm
                    rm -rf helm.tar.gz linux-amd64
                fi
                
                echo "=== Setting up Monitoring Namespace ==="
                # Create monitoring namespace
                minikube kubectl --profile=jenkins-minikube -- \
                    create namespace monitoring --dry-run=client -o yaml | \
                minikube kubectl --profile=jenkins-minikube -- apply -f -
                
                # Add Helm repos
                echo "=== Adding Helm Repositories ==="
                helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
                helm repo add grafana https://grafana.github.io/helm-charts
                helm repo update
                
                echo "=== Installing Prometheus ==="
                # Install Prometheus
                helm upgrade --install prometheus prometheus-community/prometheus \
                    --namespace monitoring \
                    --set server.service.type=NodePort \
                    --set server.service.nodePort=30090 \
                    --set alertmanager.enabled=false \
                    --set prometheus-pushgateway.enabled=false \
                    --set server.persistentVolume.enabled=false \
                    --wait \
                    --timeout=5m
                
                echo "=== Installing Grafana ==="
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
                echo "=== Monitoring Stack Status ==="
                minikube kubectl --profile=jenkins-minikube -- get all -n monitoring
                
                # Get URLs
                echo ""
                echo "=== Monitoring URLs ==="
                echo "Prometheus:"
                minikube service prometheus-server -n monitoring --profile=jenkins-minikube --url
                echo ""
                echo "Grafana:"
                GRAFANA_URL=$(minikube service grafana -n monitoring --profile=jenkins-minikube --url)
                echo "$GRAFANA_URL"
                echo "Grafana credentials: admin / admin"
                echo ""
                
                echo "Monitoring deployment completed successfully!"
                '''
            }
        }

        stage('Verification & Testing') {
            steps {
                sh '''
                export PATH=$MINIKUBE_HOME/bin:$PATH
                
                echo "=========================================="
                echo "DEPLOYMENT VERIFICATION SUMMARY"
                echo "=========================================="
                
                # Get all pods
                echo ""
                echo "=== All Pods Status ==="
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    get pods --all-namespaces -o wide
                
                # Get all services
                echo ""
                echo "=== All Services ==="
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    get svc --all-namespaces
                
                # Application logs
                echo ""
                echo "=== Spring Boot Application Logs (last 20 lines) ==="
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    logs -n devops deployment/devops-app --tail=20 || echo "Logs not available yet"
                
                # MySQL logs
                echo ""
                echo "=== MySQL Logs (last 10 lines) ==="
                $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                    logs -n devops deployment/mysql --tail=10 || echo "Logs not available yet"
                
                echo ""
                echo "=========================================="
                echo "ACCESS INFORMATION"
                echo "=========================================="
                echo ""
                echo "Application URL:"
                $MINIKUBE_HOME/bin/minikube service devops-app-service -n devops --profile=jenkins-minikube --url
                echo ""
                echo "Prometheus URL:"
                $MINIKUBE_HOME/bin/minikube service prometheus-server -n monitoring --profile=jenkins-minikube --url
                echo ""
                echo "Grafana URL:"
                $MINIKUBE_HOME/bin/minikube service grafana -n monitoring --profile=jenkins-minikube --url
                echo "(Username: admin, Password: admin)"
                echo ""
                echo "=========================================="
                '''
            }
        }
    }

    post {
        always {
            sh '''
            echo "Pipeline execution completed"
            '''
        }
        success {
            echo 'Pipeline completed successfully! ✅'
        }
        failure {
            sh '''
            export PATH=$MINIKUBE_HOME/bin:$PATH
            
            echo "=========================================="
            echo "DEBUGGING INFORMATION"
            echo "=========================================="
            
            echo ""
            echo "=== Minikube Status ==="
            $MINIKUBE_HOME/bin/minikube status --profile=jenkins-minikube || echo "Minikube not running"
            
            echo ""
            echo "=== Minikube Logs (last 100 lines) ==="
            $MINIKUBE_HOME/bin/minikube logs --profile=jenkins-minikube --length=100 || echo "Cannot retrieve logs"
            
            echo ""
            echo "=== All Pods Status ==="
            $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- get pods -A || echo "Cannot get pods"
            
            echo ""
            echo "=== Failed/Pending Pods Details ==="
            $MINIKUBE_HOME/bin/minikube kubectl --profile=jenkins-minikube -- \
                get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded || echo "No failed pods or cannot access"
            
            echo ""
            echo "=== Docker Containers ==="
            docker ps -a | grep minikube || echo "No Minikube containers"
            
            echo ""
            echo "=== Disk Space ==="
            df -h
            
            echo ""
            echo "=== Docker Disk Usage ==="
            docker system df
            
            echo "=========================================="
            '''
        }
        cleanup {
            sh '''
            # Optional: Uncomment to clean up Minikube after each run
            # export PATH=$MINIKUBE_HOME/bin:$PATH
            # $MINIKUBE_HOME/bin/minikube stop --profile=jenkins-minikube || true
            
            echo "Cleanup stage completed"
            '''
        }
    }
}
