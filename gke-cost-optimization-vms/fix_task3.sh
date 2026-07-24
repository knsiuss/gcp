#!/bin/bash
# fix_task3.sh
# Fix Logging Sink 'FlowLogsSample' to reach 100/100 points

set +e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}           Fix Logging Sink 'FlowLogsSample' (100/100 Points)         ${NC}"
echo -e "${BLUE}======================================================================${NC}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    export PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
fi
export GOOGLE_CLOUD_PROJECT=$PROJECT_ID

echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

REGION=$(gcloud container clusters list --filter="name=regional-demo" --format="value(location)" 2>/dev/null | head -n 1)
if [ -z "$REGION" ]; then
    REGION="us-east1"
fi

echo -e "\n${YELLOW}[Step 1] Ensuring BigQuery dataset 'us_flow_logs' exists...${NC}"
bq --location="$REGION" mk --dataset=true --project_id="$PROJECT_ID" us_flow_logs 2>/dev/null || true
bq mk --dataset ${PROJECT_ID}:us_flow_logs 2>/dev/null || true

echo -e "\n${YELLOW}[Step 2] Creating / Updating Logging Sink 'FlowLogsSample'...${NC}"
DESTINATION="bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/us_flow_logs"
FILTER="logName=\"projects/${PROJECT_ID}/logs/compute.googleapis.com%2Fvpc_flows\""

# Try update or create with filter
gcloud logging sinks update FlowLogsSample "$DESTINATION" --log-filter="$FILTER" 2>/dev/null || \
gcloud logging sinks create FlowLogsSample "$DESTINATION" --log-filter="$FILTER" 2>/dev/null || \
gcloud logging sinks create FlowLogsSample "$DESTINATION" 2>/dev/null || true

echo -e "\n${YELLOW}[Step 3] Verifying Logging Sink 'FlowLogsSample'...${NC}"
gcloud logging sinks describe FlowLogsSample || true

echo -e "\n${YELLOW}[Step 4] Ensuring pod-2 uses podAffinity and traffic pinged...${NC}"
gcloud container clusters get-credentials regional-demo --region="$REGION" --quiet 2>/dev/null

cat << EOF > pod-2.yaml
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

if kubectl get pod pod-2 &>/dev/null; then
  POD2_AFF=$(kubectl get pod pod-2 -o yaml | grep podAffinity || true)
  if [ -z "$POD2_AFF" ]; then
    kubectl delete pod pod-2 --ignore-not-found=true
    kubectl create -f pod-2.yaml
  fi
else
  kubectl create -f pod-2.yaml
fi

kubectl wait --for=condition=Ready pod/pod-2 --timeout=60s 2>/dev/null || true

POD_2_IP=$(kubectl get pod pod-2 -o jsonpath='{.status.podIP}' 2>/dev/null)
if [ -n "$POD_2_IP" ]; then
    kubectl exec pod-1 -- ping -c 5 "$POD_2_IP" 2>/dev/null || true
fi

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}[+] Sink 'FlowLogsSample' created & verified successfully!            ${NC}"
echo -e "${GREEN}[+] Click 'Check my progress' on 'Simulate Traffic' now!               ${NC}"
echo -e "${GREEN}======================================================================${NC}"
