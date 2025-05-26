pipeline {
  agent any
  environment {
        AWS_ACCESS_KEY_ID     = credentials('aws_cred')
        AWS_SECRET_ACCESS_KEY = credentials('aws_cred')
        DOCKER_HUB_CREDENTIALS = credentials('dockerhub_id')
        SSH_PRIVATE_KEY = credentials('jenkins-ssh-key')
    }
  stages {
    stage('Clone Repo') {
      steps {
        git 'https://github.com/StarAgileDevOpsTraining/star-agile-health-care.git'
      }
    }

    stage('Build') {
      steps {
        sh 'mvn clean package'
      }
    }

    // Stage 3: Build Docker Image
    stage('Build Docker Image') {
      steps {
        sh '''
          docker build -t shubhamtrip16/medicure:${BUILD_ID} .
          docker images
        '''
      }
    }
    // Stage 4: Push Docker Image to Docker Hub
    stage('Docker Push') {
         steps {
               withCredentials([usernamePassword(credentialsId: 'dockerhub_id', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
               sh '''
                  echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                  docker push shubhamtrip16/medicure:${BUILD_ID}
                   '''
                }
            }
    }

    stage('Provision K8s Test Cluster') {
      steps {
        script {
          // Create terraform.tfvars with the SSH key from Jenkins credentials
          withCredentials([sshUserPrivateKey(credentialsId: 'jenkins-ssh-key', keyFileVariable: 'SSH_KEY')]) {
            sh '''  
              terraform init
              terraform apply -auto-approve
              
              # Clean up sensitive files
              rm public_key.pub
            '''
          }
        }
        sh 'ansible-playbook kube-cluster.yml -i inventory.ini'
      }
    }

    stage('Deploy to Test (K8s)') {
      steps {
        sh 'kubectl apply -f k8s/test-deployment.yaml'
      }
    }

    stage('Run Selenium Test') {
      steps {
        sh 'selenium-side-runner medicure-tests.side'
      }
    }

    stage('Deploy to Prod') {
      when {
        expression {
          currentBuild.result == null || currentBuild.result == 'SUCCESS'
        }
      }
      steps {
        sh 'kubectl apply -f k8s/prod-deployment.yaml'
      }
    }

  }
}