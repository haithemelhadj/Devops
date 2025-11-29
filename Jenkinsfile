pipeline {
    agent any

    tools {
        maven 'maven-3' // Nom de Maven défini dans Jenkins → Manage Jenkins → Tools
        jdk 'Java 17'   // Nom du JDK configuré dans Jenkins
    }

    stages {
        stage('Checkout') {
            steps {
                // Récupération du code depuis Git
                git branch: 'main', url: 'https://github.com/ton-user/ton-projet.git'
            }
        }

        stage('Build') {
            steps {
                // Build Maven et package le projet
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Archive') {
            steps {
                // Archive le .jar généré pour consultation dans Jenkins
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }
    }
}
