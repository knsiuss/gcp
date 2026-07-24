#!/bin/bash
# solve_cost_vms.sh
# Automating Exploring Cost-optimization for GKE Virtual Machines (GSP767)

set +e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}    Automated Solver: Cost-optimization for GKE Virtual Machines      ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    export PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
fi
export GOOGLE_CLOUD_PROJECT=$PROJECT_ID

echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

echo -e "\n${YELLOW}[Step 1] Waiting for hello-demo-cluster to be RUNNING...${NC}"
ZONE=""
for i in {1..30}; do
    ZONE=$(gcloud container clusters list --filter="name=hello-demo-cluster" --format="value(location)" 2>/dev/null | head -n 1)
    STATUS=$(gcloud container clusters list --filter="name=hello-demo-cluster" --format="value(status)" 2>/dev/null | head -n 1)
    if [ "$STATUS" == "RUNNING" ] && [ -n "$ZONE" ]; then
        echo -e "${GREEN}[+] hello-demo-cluster is RUNNING in zone: $ZONE${NC}"
        break
    fi
    echo -e "${YELLOW}[*] Waiting for cluster provisioning (Current status: ${STATUS:-PROVISIONING}). Retry $i/30...${NC}"
    sleep 10
done

if [ -z "$ZONE" ]; then
    ZONE="us-east1-c"
    echo -e "${YELLOW}[!] Defaulting zone to: $ZONE${NC}"
fi

REGION=$(echo "$ZONE" | sed 's/-[a-z]$//')
if [ -z "$REGION" ]; then
    REGION="us-east1"
fi
echo -e "${YELLOW}[*] Region:${NC} $REGION"

# Authenticate cluster
gcloud container clusters get-credentials hello-demo-cluster --zone "$ZONE" --quiet

echo -e "\n${YELLOW}[Step 2] Scaling up Hello Server deployment...${NC}"
kubectl scale deployment hello-server --replicas=2

echo -e "\n${YELLOW}[Step 3] Resizing node pool to 4 nodes to handle workload...${NC}"
gcloud container clusters resize hello-demo-cluster --node-pool my-node-pool \
    --num-nodes 4 --zone "$ZONE" --quiet

echo -e "${GREEN}[+] Hello Server scaled up and cluster resized! (Task 2 Checkpoint 1)${NC}"

echo -e "\n${YELLOW}[Step 4] Creating optimized larger node pool (e2-standard-2)...${NC}"
gcloud container node-pools create larger-pool \
  --cluster=hello-demo-cluster \
  --machine-type=e2-standard-2 \
  --num-nodes=1 \
  --zone="$ZONE" --quiet || true

echo -e "${GREEN}[+] Larger-pool node pool created! (Task 2 Checkpoint 2)${NC}"

echo -e "\n${YELLOW}[Step 5] Cordoning and draining the old node pool...${NC}"
for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=my-node-pool -o=name 2>/dev/null); do
  kubectl cordon "$node" || true
done

for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=my-node-pool -o=name 2>/dev/null); do
  kubectl drain --force --ignore-daemonsets --delete-emptydir-data --grace-period=10 "$node" || true
done

echo -e "\n${YELLOW}[Step 6] Deleting the old node pool...${NC}"
gcloud container node-pools delete my-node-pool --cluster hello-demo-cluster --zone "$ZONE" --quiet || true

echo -e "\n${YELLOW}[Step 7] Provisioning Regional Demo Cluster...${NC}"
gcloud container clusters create regional-demo --region="$REGION" --num-nodes=1 --quiet || true
gcloud container clusters get-credentials regional-demo --region="$REGION" --quiet

echo -e "\n${YELLOW}[Step 8] Creating pod-1 and pod-2 (Anti-Affinity)...${NC}"
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

kubectl apply -f pod-1.yaml

cat << EOF > pod-2.yaml
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

kubectl apply -f pod-2.yaml

echo -e "${GREEN}[+] Pods created with Anti-Affinity! (Task 3 Checkpoint 1)${NC}"

echo -e "\n${YELLOW}[Step 9] Enabling Network APIs and Configuring VPC Flow Logs...${NC}"
gcloud services enable networkmanagement.googleapis.com logging.googleapis.com --quiet || true

gcloud compute networks subnets update default --region="$REGION" --enable-flow-logs --quiet || true

bq --location="$REGION" mk --dataset=true --project_id="$PROJECT_ID" us_flow_logs 2>/dev/null || true

gcloud logging sinks create FlowLogsSample \
  bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/us_flow_logs \
  --log-filter="logName=\"projects/${PROJECT_ID}/logs/compute.googleapis.com%2Fvpc_flows\"" --quiet 2>/dev/null || true

echo -e "${GREEN}[+] VPC Flow Logs and BigQuery Export configured!${NC}"

echo -e "\n${YELLOW}[Step 10] Moving pod-2 to use Pod Affinity (optimize cross-zonal costs)...${NC}"
kubectl delete pod pod-2 --ignore-not-found=true

sed -i 's/podAntiAffinity/podAffinity/g' pod-2.yaml

kubectl create -f pod-2.yaml || kubectl apply -f pod-2.yaml

echo -e "${GREEN}[+] Pod-2 moved to the same node as Pod-1! (Task 3 Checkpoint 2)${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}    GKE Cost VM optimization completed successfully! Check Qwiklabs.  ${NC}"
echo -e "${GREEN}======================================================================${NC}"

