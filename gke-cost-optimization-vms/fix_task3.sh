#!/bin/bash
# fix_task3.sh
# Fix Task 3 checkpoints for GSP767

set +e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}                 Fix Task 3 (Managing Regional Cluster)               ${NC}"
echo -e "${BLUE}======================================================================${NC}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    export PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
fi
export GOOGLE_CLOUD_PROJECT=$PROJECT_ID

REGION=$(gcloud container clusters list --filter="name=regional-demo" --format="value(location)" 2>/dev/null | head -n 1)
if [ -z "$REGION" ]; then
    REGION="us-east1"
fi

echo -e "${YELLOW}[*] Authenticating to regional-demo cluster in $REGION...${NC}"
gcloud container clusters get-credentials regional-demo --region="$REGION" --quiet

echo -e "\n${YELLOW}[Phase 1] Setting up Pod Anti-Affinity (Task 3 Checkpoint: Check Pod Creation)...${NC}"
kubectl delete pod pod-1 pod-2 --ignore-not-found=true

cat << EOF > pod-1.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-1
  labels:
    security: demo
spec:
  containers:
  - name: container-1
    image: wbitt/network-multitool
EOF

cat << EOF > pod-2-anti.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-2
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: security
            operator: In
            values:
            - demo
        topologyKey: "kubernetes.io/hostname"
  containers:
  - name: container-2
    image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
EOF

kubectl apply -f pod-1.yaml
kubectl apply -f pod-2-anti.yaml

echo -e "${YELLOW}[*] Waiting for pod-1 and pod-2 to be Ready...${NC}"
kubectl wait --for=condition=Ready pod/pod-1 --timeout=60s 2>/dev/null
kubectl wait --for=condition=Ready pod/pod-2 --timeout=60s 2>/dev/null

POD_2_IP=$(kubectl get pod pod-2 -o jsonpath='{.status.podIP}' 2>/dev/null)
if [ -n "$POD_2_IP" ]; then
    echo -e "${YELLOW}[*] Simulating traffic (pinging pod-2 at $POD_2_IP)...${NC}"
    kubectl exec pod-1 -- ping -c 4 "$POD_2_IP" 2>/dev/null || true
fi

echo -e "\n${GREEN}[>>>] ACTION REQUIRED:${NC}"
echo -e "${GREEN}1. Click 'Check my progress' for 'Check Pod Creation' in Qwiklabs NOW!${NC}"
echo -e "${YELLOW}Waiting 15 seconds before moving to Phase 2...${NC}"
sleep 15

echo -e "\n${YELLOW}[Phase 2] Configuring VPC Flow Logs and BigQuery Sink...${NC}"
gcloud services enable networkmanagement.googleapis.com logging.googleapis.com --quiet || true
gcloud compute networks subnets update default --region="$REGION" --enable-flow-logs --quiet || true
bq --location="$REGION" mk --dataset=true --project_id="$PROJECT_ID" us_flow_logs 2>/dev/null || true

gcloud logging sinks create FlowLogsSample \
  bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/us_flow_logs \
  --log-filter="resource.type=\"gce_subnetwork\" OR logName=\"projects/${PROJECT_ID}/logs/compute.googleapis.com%2Fvpc_flows\"" --quiet 2>/dev/null || true

echo -e "\n${YELLOW}[Phase 3] Converting to Pod Affinity (Task 3 Checkpoint: Simulate Traffic)...${NC}"
kubectl delete pod pod-2 --ignore-not-found=true

cat << EOF > pod-2-affinity.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-2
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: security
            operator: In
            values:
            - demo
        topologyKey: "kubernetes.io/hostname"
  containers:
  - name: container-2
    image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
EOF

kubectl apply -f pod-2-affinity.yaml

echo -e "${YELLOW}[*] Waiting for pod-2 to be Ready on the same node...${NC}"
kubectl wait --for=condition=Ready pod/pod-2 --timeout=60s 2>/dev/null

POD_2_IP=$(kubectl get pod pod-2 -o jsonpath='{.status.podIP}' 2>/dev/null)
if [ -n "$POD_2_IP" ]; then
    echo -e "${YELLOW}[*] Simulating traffic in same zone (pinging pod-2 at $POD_2_IP)...${NC}"
    kubectl exec pod-1 -- ping -c 4 "$POD_2_IP" 2>/dev/null || true
fi

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}[>>>] ACTION REQUIRED:${NC}"
echo -e "${GREEN}2. Click 'Check my progress' for 'Simulate Traffic' in Qwiklabs NOW!${NC}"
echo -e "${GREEN}======================================================================${NC}"
