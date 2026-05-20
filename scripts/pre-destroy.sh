#!/bin/bash
echo "=== Pre-destroy cleanup ==="

echo "1. Eliminando Service de Kubernetes..."
kubectl delete svc pipeline-demo-service --ignore-not-found=true

echo "2. Esperando que AWS elimine el Load Balancer..."
sleep 60

echo "3. Verificando Load Balancers..."
aws elb describe-load-balancers --region eu-west-1 \
  --query 'LoadBalancerDescriptions[*].LoadBalancerName' \
  --output table

echo "4. Listo para ejecutar terraform destroy"
