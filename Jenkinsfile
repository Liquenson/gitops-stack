pipeline {
    agent any
    
    environment {
        AWS_REGION = 'eu-west-1'
        ECR_REGISTRY = '538079272432.dkr.ecr.eu-west-1.amazonaws.com'
        IMAGE_NAME = 'gitops-stack'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }
    
    stages {
        stage('Test') {
            steps {
                echo 'Ejecutando tests...'
                sh 'pip install -r app/requirements.txt --break-system-packages'
                sh 'pytest tests/'
            }
        }
        
        stage('Build imagen Docker') {
            steps {
                echo 'Construyendo imagen Docker...'
                sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
            }
        }
        
        stage('Push a ECR') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    echo 'Publicando imagen en ECR...'
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                    """
                }
            }
        }
        
        stage('Deploy con Terraform') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    echo 'Desplegando infraestructura con Terraform...'
                    dir('terraform') {
                        sh 'terraform init'
                        sh 'terraform plan'
                        input message: '¿Aplicar cambios en producción?'
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }

        stage('Configurar nodos con Ansible') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    echo 'Configurando nodos con Ansible...'
                    sh """
                        export NODE1_IP=\$(aws ec2 describe-instances \
                            --region ${AWS_REGION} \
                            --filters "Name=tag:eks:cluster-name,Values=gitops-stack-prod" \
                            --query 'Reservations[0].Instances[0].PrivateIpAddress' \
                            --output text)

                        export NODE2_IP=\$(aws ec2 describe-instances \
                            --region ${AWS_REGION} \
                            --filters "Name=tag:eks:cluster-name,Values=gitops-stack-prod" \
                            --query 'Reservations[1].Instances[0].PrivateIpAddress' \
                            --output text)

                        echo "Nodo 1: \$NODE1_IP"
                        echo "Nodo 2: \$NODE2_IP"

                        cd ansible
                        ansible-playbook site.yml \
                            --extra-vars "node1_ip=\$NODE1_IP node2_ip=\$NODE2_IP"
                    """
                }
            }
        }
        
        stage('Actualizar Kubernetes') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials'
                ]]) {
                    echo 'Conectando a EKS y desplegando...'
                    sh """
                        aws eks update-kubeconfig --region ${AWS_REGION} --name gitops-stack-prod
                        kubectl set image deployment/pipeline-demo \
                        pipeline-demo=${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completado con éxito'
        }
        failure {
            echo 'Pipeline fallido — revisar logs'
        }
    }
}
