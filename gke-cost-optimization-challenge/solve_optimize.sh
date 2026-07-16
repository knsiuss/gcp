#!/bin/bash
# solve_optimize.sh
# Automating Optimize Costs for Google Kubernetes Engine: Challenge Lab (GSP343)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}    Automated Solver: GKE Cost Optimization Challenge (GSP343)       ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project)
export GOOGLE_CLOUD_PROJECT=$PROJECT_ID

echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

# Detect default zone
ZONE=$(gcloud config get-value compute/zone 2>/dev/null || echo "")
if [ -z "$ZONE" ]; then
    ZONE=$(gcloud compute zones list --filter="status=UP" --format="value(name)" | head -n 1 || echo "")
fi

# Ask user for variables
if [ -z "$CLUSTER_NAME" ]; then
    read -p "Enter Cluster Name (from Qwiklabs, e.g. onlineboutique-cluster-285): " CLUSTER_NAME
fi

if [ -z "$ZONE" ]; then
    read -p "Enter Zone (from Qwiklabs, e.g. us-central1-b): " ZONE
fi

if [ -z "$POOL_NAME" ]; then
    read -p "Enter Pool Name (from Qwiklabs, e.g. optimized-pool-285): " POOL_NAME
fi

if [ -z "$MAX_REPLICAS" ]; then
    read -p "Enter Max Replicas (from Qwiklabs Task 4, e.g. 12): " MAX_REPLICAS
fi

echo -e "\n${YELLOW}[Step 1] Creating Cluster '$CLUSTER_NAME' in '$ZONE'...${NC}"
gcloud container clusters create "$CLUSTER_NAME" \
    --zone "$ZONE" \
    --machine-type "e2-standard-2" \
    --num-nodes 2 \
    --release-channel "rapid" --quiet

gcloud container clusters get-credentials "$CLUSTER_NAME" --zone "$ZONE"

echo -e "\n${YELLOW}[Step 2] Creating Namespaces (dev, prod)...${NC}"
kubectl create namespace dev
kubectl create namespace prod

echo -e "\n${YELLOW}[Step 3] Deploying OnlineBoutique application...${NC}"
git clone https://github.com/GoogleCloudPlatform/microservices-demo.git || true
cd microservices-demo
kubectl apply -f ./release/kubernetes-manifests.yaml --namespace dev

echo -e "${GREEN}[+] Task 1 Completed! Check progress on Qwiklabs.${NC}"

echo -e "\n${YELLOW}[Step 4] Task 2: Migrating to Optimized Node Pool...${NC}"
gcloud container node-pools create "$POOL_NAME" \
    --cluster "$CLUSTER_NAME" \
    --machine-type=custom-2-3584 \
    --num-nodes=2 \
    --zone="$ZONE" --quiet

echo -e "${YELLOW}[*] Cordoning and draining default-pool...${NC}"
for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=default-pool -o=name); do
    kubectl cordon "$node"
done

for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=default-pool -o=name); do
    kubectl drain --force --ignore-daemonsets --delete-emptydir-data --grace-period=10 "$node"
done

echo -e "${YELLOW}[*] Deleting default-pool...${NC}"
gcloud container node-pools delete default-pool \
    --cluster "$CLUSTER_NAME" \
    --zone "$ZONE" --quiet

echo -e "${GREEN}[+] Task 2 Completed! Check progress on Qwiklabs.${NC}"

echo -e "\n${YELLOW}[Step 5] Task 3: Applying Frontend Update...${NC}"
kubectl create poddisruptionbudget onlineboutique-frontend-pdb \
    --namespace dev \
    --selector app=frontend \
    --min-available=1 || true

echo -e "${YELLOW}[*] Patching Frontend Deployment to use v2.1 image with Always Pull policy...${NC}"
kubectl patch deployment frontend --namespace dev --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value": "Always"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "gcr.io/qwiklabs-resources/onlineboutique-frontend:v2.1"}
]'

echo -e "${GREEN}[+] Task 3 Completed! Check progress on Qwiklabs.${NC}"

echo -e "\n${YELLOW}[Step 6] Task 4: Autoscaling & Load Test...${NC}"
kubectl autoscale deployment frontend \
    --cpu-percent=50 \
    --min=1 \
    --max="$MAX_REPLICAS" \
    --namespace dev

echo -e "${YELLOW}[*] Updating Cluster Autoscaler limits...${NC}"
gcloud beta container clusters update "$CLUSTER_NAME" \
    --enable-autoscaling \
    --min-nodes 1 \
    --max-nodes 6 \
    --zone "$ZONE" --quiet

echo -e "${YELLOW}[*] Scaling recommendationservice...${NC}"
kubectl autoscale deployment recommendationservice \
    --cpu-percent=50 \
    --min=1 \
    --max=5 \
    --namespace dev

echo -e "${YELLOW}[*] Retrieving Frontend External IP...${NC}"
FRONTEND_IP=""
for i in {1..30}; do
    FRONTEND_IP=$(kubectl get service frontend-external --namespace dev -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ ! -z "$FRONTEND_IP" ]; then
        break
    fi
    echo -e "${YELLOW}[*] Waiting for load balancer IP ($i/30)...${NC}"
    sleep 10
done

if [ -z "$FRONTEND_IP" ]; then
    echo -e "${RED}Warning: Frontend IP load balancer took too long. Load generator simulation skipped.${NC}"
else
    echo -e "${GREEN}[+] Frontend IP located: $FRONTEND_IP${NC}"
    echo -e "${YELLOW}[*] Simulating traffic surge...${NC}"
    LOADGENERATOR_POD=$(kubectl get pod --namespace=dev | grep 'loadgenerator' | cut -f1 -d ' ' | head -n 1)
    
    # Run locust in background for 30 seconds to trigger checkpoints
    kubectl exec "$LOADGENERATOR_POD" --namespace=dev -- sh -c "export USERS=8000; locust --host=\"http://$FRONTEND_IP\" --headless -u \"8000\" 2>&1" &
    LOAD_PID=$!
    sleep 30
    kill $LOAD_PID || true
fi

echo -e "${GREEN}[+] Task 4 Completed! Check progress on Qwiklabs.${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}    GKE Cost Optimization Challenge Completed! Check Qwiklabs.       ${NC}"
echo -e "${GREEN}======================================================================${NC}"
