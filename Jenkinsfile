pipeline {
  agent any
  environment {
        AWS_ACCESS_KEY_ID     = credentials('aws_cred')
        AWS_SECRET_ACCESS_KEY = credentials('aws_cred')
        DOCKER_HUB_CREDENTIALS = credentials('dockerhub_id')
        SSH_PRIVATE_KEY = credentials('jenkins-ssh-key')
    }
  stages {
    stage('Cloning Repo') {
      steps {
        git branch: 'main', url: 'https://github.com/ShubhamTrip/Medicure.git'
      }
    }

    stage('Build') {
      steps {
        sh 'mvn clean package'
      }
    }

    stage('Build Docker Image') {
      steps {
        sh '''
          docker build -t shubhamtrip16/medicure:${BUILD_ID} .
          docker images
        '''
      }
    }

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

    stage('Provision Infra') {
      steps {
        withCredentials([file(credentialsId: 'jenkins-ssh-key', variable: 'SSH_KEY_FILE')]) {
          sh '''
            cd terraform
            # Create terraform.tfvars with required variables
            echo 'environment = "test"' > terraform.tfvars
            # Extract public key from private key file and add to terraform.tfvars
            ssh-keygen -y -f "$SSH_KEY_FILE" > public_key.pub
            echo "public_key = \\"$(cat public_key.pub)\\"" >> terraform.tfvars
            
            terraform init
            terraform apply -auto-approve
            
            # Clean up sensitive files
            rm public_key.pub
          '''
        }
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