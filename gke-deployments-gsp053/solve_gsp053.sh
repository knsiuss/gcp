#!/bin/bash
# ============================================================================
# GSP053 - Managing Deployments Using Kubernetes Engine
# Creates bootcamp cluster, fortune-app deployments, rolling update, canary,
# and blue-green deployments with the sample code from gs://spls/gsp053.
#
# Usage (in the lab's Cloud Shell):
#   git clone https://github.com/knsiuss/gcp.git gcp-labs
#   cd gcp-labs/gke-deployments-gsp053
#   chmod +x solve_gsp053.sh
#   ./solve_gsp053.sh
#   -> prompts for the ZONE (from the lab page)
# ============================================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

ACTIVE_ACCOUNT=$(gcloud auth list --format="value(account)" 2>/dev/null | head -1)
[ -n "$ACTIVE_ACCOUNT" ] && gcloud config set account "$ACTIVE_ACCOUNT" --quiet 2>/dev/null || true
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
[ -z "$PROJECT_ID" ] && PROJECT_ID="$DEVSHELL_PROJECT_ID"

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP053 - Managing Deployments Using Kubernetes Engine Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project: ${PROJECT_ID}${NC}"
echo
printf "${YELLOW}Enter the ZONE from the lab page (e.g. us-central1-f): ${NC}"
read -p "" ZONE
[ -z "$ZONE" ] && ZONE="us-central1-f"
echo -e "${CYAN}[*] Using zone: $ZONE${NC}"
gcloud config set compute/zone "$ZONE" --quiet 2>/dev/null || true

SRV_IP() { kubectl get svc fortune-app -o=jsonpath="{.status.loadBalancer.ingress[0].ip}"; }
VERSION() { curl -s "http://$(SRV_IP)/version" 2>/dev/null; }

# ============================================================================
# Setup: sample code + cluster
# ============================================================================
echo -e "\n${YELLOW}[Setup] Downloading sample code...${NC}"
if [ ! -d "$HOME/kubernetes/deployments" ]; then
  gcloud storage cp -r gs://spls/gsp053/kubernetes "$HOME/" 2>/dev/null \
    || gsutil cp -r gs://spls/gsp053/kubernetes "$HOME/"
fi
cd "$HOME/kubernetes"
echo -e "${GREEN}  [OK] Sample code ready.${NC}"

echo -e "\n${YELLOW}[Setup] Creating bootcamp cluster (3x e2-small)...${NC}"
if gcloud container clusters describe bootcamp --zone="$ZONE" >/dev/null 2>&1; then
  echo "  Cluster bootcamp already exists."
else
  gcloud container clusters create bootcamp \
    --machine-type e2-small \
    --num-nodes 3 \
    --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw" \
    --quiet --no-user-output-enabled 2>/dev/null \
    || gcloud container clusters create bootcamp \
         --machine-type e2-small --num-nodes 3 \
         --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw"
  echo -e "${GREEN}  [OK] Cluster created.${NC}"
fi
gcloud container clusters get-credentials bootcamp --zone="$ZONE" --quiet

# ============================================================================
# Task 1: deployment object explain
# ============================================================================
echo -e "\n${YELLOW}[Task 1] kubectl explain deployment...${NC}"
kubectl explain deployment >/dev/null
echo -e "${GREEN}  [OK] Task 1 (explain) done.${NC}"

# ============================================================================
# Task 2: create fortune-app-blue deployment + service, scale
# ============================================================================
echo -e "\n${YELLOW}[Task 2] Creating fortune-app-blue deployment + service...${NC}"
kubectl create -f deployments/fortune-app-blue.yaml
kubectl create -f services/fortune-app.yaml 2>/dev/null || kubectl apply -f services/fortune-app.yaml
kubectl get deployments
kubectl get replicasets
kubectl get pods

echo "  Waiting for External-IP..."
for i in $(seq 1 30); do IP=$(SRV_IP); [ -n "$IP" ] && break; sleep 10; done
echo "  External IP: $IP"
echo "  /version -> $(VERSION)"

echo -e "\n${YELLOW}[Task 2 cont.] Scaling 3 -> 5 -> 3...${NC}"
kubectl scale deployment fortune-app-blue --replicas=5
until [ "$(kubectl get pods -l app=fortune-app -o name | wc -l)" == "5" ]; do sleep 5; done
echo "  After scale up: $(kubectl get pods -l app=fortune-app -o name | wc -l) pods"
kubectl scale deployment fortune-app-blue --replicas=3
until [ "$(kubectl get pods -l app=fortune-app -o name | wc -l)" == "3" ]; do sleep 5; done
echo "  After scale down: $(kubectl get pods -l app=fortune-app -o name | wc -l) pods"
echo -e "${GREEN}  [OK] Task 2 done. Check progress.${NC}"

# ============================================================================
# Task 3: rolling update (1.0.0 -> 2.0.0), pause, resume, rollback
# ============================================================================
echo -e "\n${YELLOW}[Task 3] Rolling update to 2.0.0...${NC}"
kubectl set image deployment/fortune-app-blue fortune-app=us-central1-docker.pkg.dev/qwiklabs-resources/spl-lab-apps/fortune-service:2.0.0
kubectl set env deployment/fortune-app-blue APP_VERSION=2.0.0
kubectl rollout status deployment/fortune-app-blue
kubectl rollout history deployment/fortune-app-blue

echo -e "\n${YELLOW}[Task 3 cont.] Pause rolling update...${NC}"
kubectl rollout pause deployment/fortune-app-blue
kubectl rollout status deployment/fortune-app-blue || true

echo -e "\n${YELLOW}[Task 3 cont.] Resume rolling update...${NC}"
kubectl rollout resume deployment/fortune-app-blue
kubectl rollout status deployment/fortune-app-blue

echo -e "\n${YELLOW}[Task 3 cont.] Roll back to 1.0.0...${NC}"
kubectl rollout undo deployment/fortune-app-blue
kubectl rollout status deployment/fortune-app-blue
echo "  /version -> $(VERSION)"
echo -e "${GREEN}  [OK] Task 3 (rolling update) done. Check progress.${NC}"

# ============================================================================
# Task 4: canary deployment
# ============================================================================
echo -e "\n${YELLOW}[Task 4] Creating canary deployment...${NC}"
kubectl create -f deployments/fortune-app-canary.yaml
kubectl get deployments
for i in {1..10}; do VERSION; done
echo -e "${GREEN}  [OK] Task 4 (canary) done. Check progress.${NC}"

# ============================================================================
# Task 5: blue-green deployment
# ============================================================================
echo -e "\n${YELLOW}[Task 5] Blue-green deployment...${NC}"
kubectl apply -f services/fortune-app-blue-service.yaml
kubectl create -f deployments/fortune-app-green.yaml
kubectl rollout status deployment/fortune-app-green
echo "  Before switch (should be 1.0.0): $(VERSION)"
kubectl apply -f services/fortune-app-green-service.yaml
sleep 5
echo "  After switch  (should be 2.0.0): $(VERSION)"
echo -e "\n${YELLOW}[Task 5 cont.] Blue-green rollback...${NC}"
kubectl apply -f services/fortune-app-blue-service.yaml
sleep 5
echo "  After rollback (should be 1.0.0): $(VERSION)"
echo -e "${GREEN}  [OK] Task 5 (blue-green) done. Check progress.${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP053 SOLVER FINISHED - click 'Check my progress' for all tasks.${NC}"
echo -e "${GREEN}======================================================================${NC}"