#!/bin/bash
# solve_gsp510.sh
# Automating GSP510: Manage Kubernetes in Google Cloud: Challenge Lab (Task 6)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}    Automated Solver: GKE Manage Kubernetes Challenge (GSP510)       ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project)
echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

# Auto-detect GKE Cluster details
CLUSTER_NAME=$(gcloud container clusters list --format="value(name)" | head -n 1)
CLUSTER_ZONE=$(gcloud container clusters list --format="value(zone)" | head -n 1)

if [ -z "$CLUSTER_NAME" ]; then
    echo -e "${RED}[-] No GKE cluster found. Please make sure the cluster is created.${NC}"
    exit 1
fi

echo -e "${YELLOW}[*] Cluster Name:${NC} $CLUSTER_NAME"
echo -e "${YELLOW}[*] Cluster Zone:${NC} $CLUSTER_ZONE"

# Get GKE credentials
gcloud container clusters get-credentials "$CLUSTER_NAME" --zone="$CLUSTER_ZONE" --quiet

# Detect Namespace (looking for gmp-* namespace)
NAMESPACE=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -E '^gmp-[a-z0-9]+$' | head -n 1)
if [ -z "$NAMESPACE" ]; then
    NAMESPACE="gmp-i82r"
fi
echo -e "${YELLOW}[*] Target Namespace:${NC} $NAMESPACE"

# Detect Artifact Registry Location for hello-repo
REPO_PATH=$(gcloud artifacts repositories list --filter="name:hello-repo" --format="value(name)" | head -n 1)
if [ -z "$REPO_PATH" ]; then
    echo -e "${RED}[-] Artifact Registry repository 'hello-repo' not found.${NC}"
    exit 1
fi
REGISTRY_LOCATION=$(echo "$REPO_PATH" | cut -d'/' -f4)
echo -e "${YELLOW}[*] Artifact Registry Location:${NC} $REGISTRY_LOCATION"

# Prompt for the Service Name (Task 6 service name, e.g. helloweb-service-epim)
if [ -z "$SERVICE_NAME" ]; then
    read -p "Enter the service name from Task 6 (e.g. helloweb-service-epim): " SERVICE_NAME
fi

if [ -z "$SERVICE_NAME" ]; then
    echo -e "${RED}[-] Service name cannot be empty.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}[Step 1] Modifying main.go to Version 2.0.0...${NC}"
if [ -d "hello-app" ]; then
    cd hello-app
else
    echo -e "${RED}[-]'hello-app' directory not found. Downloading sources...${NC}"
    gcloud storage cp -r gs://spls/gsp510/hello-app/ .
    cd hello-app
fi

# Update version in main.go
sed -i 's/1.0.0/2.0.0/g' main.go
echo -e "${GREEN}[+] version set to 2.0.0 in main.go${NC}"

echo -e "\n${YELLOW}[Step 2] Building Docker Image (v2)...${NC}"
IMAGE_NAME="${REGISTRY_LOCATION}-docker.pkg.dev/${PROJECT_ID}/hello-repo/hello-app:v2"

# Authenticate Docker to Registry
gcloud auth configure-docker "${REGISTRY_LOCATION}-docker.pkg.dev" --quiet

# Build and Push
docker build -t "$IMAGE_NAME" .
docker push "$IMAGE_NAME"
echo -e "${GREEN}[+] Docker image v2 pushed successfully!${NC}"

# Navigate back
cd ..

echo -e "\n${YELLOW}[Step 3] Updating GKE Deployment image to v2...${NC}"
# Get container name dynamically
CONTAINER_NAME=$(kubectl get deployment helloweb --namespace="$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].name}')
if [ -z "$CONTAINER_NAME" ]; then
    CONTAINER_NAME="helloweb"
fi

kubectl set image deployment/helloweb "$CONTAINER_NAME"="$IMAGE_NAME" --namespace="$NAMESPACE"
kubectl rollout status deployment/helloweb --namespace="$NAMESPACE"
echo -e "${GREEN}[+] GKE deployment updated to v2 image!${NC}"

echo -e "\n${YELLOW}[Step 4] Exposing helloweb deployment...${NC}"
# Delete service if already exists to prevent conflict
kubectl delete service "$SERVICE_NAME" --namespace="$NAMESPACE" || true

kubectl expose deployment helloweb \
    --name="$SERVICE_NAME" \
    --type=LoadBalancer \
    --port=8080 \
    --target-port=8080 \
    --namespace="$NAMESPACE"

echo -e "${GREEN}[+] Service exposed!${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}    Task 6 Automation Completed! Check Qwiklabs.                     ${NC}"
echo -e "${GREEN}======================================================================${NC}"
