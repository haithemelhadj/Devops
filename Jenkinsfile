pipeline {
    agent any

    tools {
        maven 'maven-3'      // name of Maven tool in Jenkins
        jdk 'Java 17'        // name of JDK tool in Jenkins
    }

    stages {
        stage('Clone Repo') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-token',
                    url: 'https://github.com/haithemelhadj/Devops.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t devops .'
            }
        }

        stage('Run Container') {
            steps {
                sh 'docker run -d --name devops_container -p 8081:80 devops'
            }
        }
    }
}
