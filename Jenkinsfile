pipeline {
  agent any
  environment {
        AWS_ACCESS_KEY_ID     = credentials('aws_cred')
        AWS_SECRET_ACCESS_KEY = credentials('aws_cred')
        DOCKER_HUB_CREDENTIALS = credentials('dockerhub_id')
        SSH_PRIVATE_KEY = credentials('jenkins-ssh-key')
        ANSIBLE_HOST_KEY_CHECKING = 'False'
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

    stage('Install Dependencies') {
      steps {
        sh '''
          # Install kubectl
          curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
          chmod +x kubectl
          sudo mv kubectl /usr/local/bin/
          
          # Verify installations
          kubectl version --client
        '''
      }
    }

    stage('Provision Infra') {
      steps {
        withCredentials([file(credentialsId: 'jenkins-ssh-key', variable: 'SSH_KEY_FILE')]) {
          sh '''
            # Create a persistent copy of the SSH key
            mkdir -p ~/.ssh
            cp "$SSH_KEY_FILE" ~/.ssh/jenkins-ssh-key
            chmod 600 ~/.ssh/jenkins-ssh-key
            
            cd terraform
            # Create terraform.tfvars with required variables
            echo 'environment = "test"' > terraform.tfvars
            # Extract public key from private key file and add to terraform.tfvars
            ssh-keygen -y -f ~/.ssh/jenkins-ssh-key > public_key.pub
            echo "public_key = \\"$(cat public_key.pub)\\"" >> terraform.tfvars
            
            terraform init
            terraform apply -auto-approve
            
            # Create Ansible inventory file
            echo "[master]" > ../ansible/inventory.ini
            terraform output -raw master_ip | tr -d '\\n' >> ../ansible/inventory.ini
            echo " ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/jenkins-ssh-key ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> ../ansible/inventory.ini
            echo "" >> ../ansible/inventory.ini
            echo "[workers]" >> ../ansible/inventory.ini
            terraform output -json worker_ips | jq -r '.[]' | while read ip; do
              echo "$ip ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/jenkins-ssh-key ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> ../ansible/inventory.ini
            done
            
            # Display inventory file for debugging
            echo "Generated inventory file:"
            cat ../ansible/inventory.ini
            
            # Clean up sensitive files
            rm public_key.pub
          '''
        }
      }
    }

    stage('Configuring server(K8s)') {
      steps {
        sh '''
          cd ansible
          # Verify SSH key exists
          ls -la ~/.ssh/jenkins-ssh-key
          
          # Test SSH connection to hosts
          ansible all -i inventory.ini -m ping -v
          
          # Run the playbook
          ansible-playbook -i inventory.ini kube-cluster.yml -v
        '''
      }
    }

    stage('Deploy to Test (K8s)') {
      steps {
        sh '''
          # Configure kubectl with the new cluster
          mkdir -p ~/.kube
          scp -o StrictHostKeyChecking=no -i ~/.ssh/jenkins-ssh-key ubuntu@$(cd terraform && terraform output -raw master_ip):.kube/config ~/.kube/config
          
          # Deploy the application
          kubectl apply -f k8s/test-deployment.yaml
        '''
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