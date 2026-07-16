#!/bin/bash
# solve_cost_vms.sh
# Automating Exploring Cost-optimization for GKE Virtual Machines (GSP767)

set -e

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
export PROJECT_ID=$(gcloud config get-value project)
export GOOGLE_CLOUD_PROJECT=$PROJECT_ID

echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

echo -e "\n${YELLOW}[Step 1] Authenticating GKE Cluster...${NC}"
# Dynamically discover the zone/location of the hello-demo-cluster
ZONE=$(gcloud container clusters list --filter="name=hello-demo-cluster" --format="value(location)" | head -n 1)

if [ -z "$ZONE" ]; then
    echo -e "${RED}Error: GKE Cluster hello-demo-cluster zone could not be detected.${NC}"
    exit 1
fi

echo -e "${YELLOW}[*] GKE Cluster Zone:${NC} $ZONE"
gcloud container clusters get-credentials hello-demo-cluster --zone "$ZONE"

echo -e "\n${YELLOW}[Step 2] Scaling up Hello Server deployment...${NC}"
kubectl scale deployment hello-server --replicas=2

echo -e "\n${YELLOW}[Step 3] Resizing node pool to 4 nodes to handle workload...${NC}"
gcloud container clusters resize hello-demo-cluster --node-pool my-node-pool \
    --num-nodes 4 --zone "$ZONE" --quiet

echo -e "${GREEN}[+] Hello Server scaled up and cluster resized! (Task 2 Scale Up Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 4] Creating optimized larger node pool (e2-standard-2)...${NC}"
gcloud container node-pools create larger-pool \
  --cluster=hello-demo-cluster \
  --machine-type=e2-standard-2 \
  --num-nodes=1 \
  --zone="$ZONE" --quiet

echo -e "${GREEN}[+] Larger-pool node pool created! (Task 2 Create Node Pool Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 5] Cordoning and draining the old node pool...${NC}"
for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=my-node-pool -o=name); do
  kubectl cordon "$node"
done

for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=my-node-pool -o=name); do
  kubectl drain --force --ignore-daemonsets --delete-emptydir-data --grace-period=10 "$node"
done

echo -e "\n${YELLOW}[Step 6] Deleting the old node pool...${NC}"
gcloud container node-pools delete my-node-pool --cluster hello-demo-cluster --zone "$ZONE" --quiet

echo -e "\n${YELLOW}[Step 7] Provisioning Regional Demo Cluster...${NC}"
# Extract region from the cluster zone
REGION=$(echo "$ZONE" | cut -d'-' -f1-2)
echo -e "${YELLOW}[*] Regional GKE Cluster Region:${NC} $REGION"

gcloud container clusters create regional-demo --region="$REGION" --num-nodes=1 --quiet
gcloud container clusters get-credentials regional-demo --region="$REGION"

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

echo -e "${GREEN}[+] Pods created with Anti-Affinity! (Task 3 Check Pod Creation Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 9] Enabling Network APIs and Configuring VPC Flow Logs...${NC}"
gcloud services enable networkmanagement.googleapis.com logging.googleapis.com --quiet

# Enable VPC Flow Logs for default subnet in the region
gcloud compute networks subnets update default --region="$REGION" --enable-flow-logs --quiet

# Create BigQuery dataset for flow logs
bq --location="$REGION" mk --dataset=true --project_id="$PROJECT_ID" us_flow_logs || true

# Create Logging Sink to export flow logs to BigQuery
gcloud logging sinks create FlowLogsSample \
  bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/us_flow_logs \
  --log-filter="logName=\"projects/${PROJECT_ID}/logs/compute.googleapis.com%2Fvpc_flows\"" --quiet

echo -e "${GREEN}[+] VPC Flow Logs and BigQuery Export configured!${NC}"

echo -e "\n${YELLOW}[Step 10] Moving pod-2 to use Pod Affinity (optimize cross-zonal costs)...${NC}"
# Delete the anti-affinity pod
kubectl delete pod pod-2 --ignore-not-found=true

# Modify the manifest to use affinity
sed -i 's/podAntiAffinity/podAffinity/g' pod-2.yaml

# Recreate the pod
kubectl create -f pod-2.yaml

echo -e "${GREEN}[+] Pod-2 moved to the same node as Pod-1! (Task 3 Simulate Traffic Checkpoint)${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}    GKE Cost VM optimization completed successfully! Check Qwiklabs.  ${NC}"
echo -e "${GREEN}======================================================================${NC}"
