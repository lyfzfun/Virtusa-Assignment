#!/bin/bash

echo "Creating Kubernetes Secrets..."
kubectl apply -f k8s/mysql-secret.yaml

echo "Deploying MySQL..."
kubectl apply -f k8s/mysql-deployment.yaml
kubectl apply -f k8s/mysql-service.yaml

echo "Initializing MySQL table..."
kubectl apply -f k8s/mysql-init-job.yaml

echo "Deploying Counter App..."
kubectl apply -f k8s/app-deployment.yaml
kubectl apply -f k8s/app-service.yaml

echo "Installing Prometheus + Grafana..."
./monitoring/prometheus-grafana-install.sh

echo "All components deployed. Access app at http://localhost:30007"
echo "Access Grafana via: kubectl port-forward svc/monitoring-grafana 3000"
echo "Login: admin / prom-operator"
