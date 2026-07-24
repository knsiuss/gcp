#!/bin/bash
# fix_task3.sh
# Complete Sink FlowLogsSample setup with IAM permissions for 100/100 points

set +e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}        Fixing Sink 'FlowLogsSample' & IAM Permissions (100/100)      ${NC}"
echo -e "${BLUE}======================================================================${NC}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    export PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
fi
export GOOGLE_CLOUD_PROJECT=$PROJECT_ID

echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

echo -e "\n${YELLOW}[Step 1] Cleaning up previous sink and dataset...${NC}"
gcloud logging sinks delete FlowLogsSample --quiet 2>/dev/null || true
bq rm -r -f -d ${PROJECT_ID}:us_flow_logs 2>/dev/null || true

echo -e "\n${YELLOW}[Step 2] Creating BigQuery dataset 'us_flow_logs' (Default Location)...${NC}"
bq mk --dataset ${PROJECT_ID}:us_flow_logs

echo -e "\n${YELLOW}[Step 3] Creating Logging Sink 'FlowLogsSample'...${NC}"
gcloud logging sinks create FlowLogsSample \
  bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/us_flow_logs \
  --log-filter="logName=\"projects/${PROJECT_ID}/logs/compute.googleapis.com%2Fvpc_flows\"" --quiet

echo -e "\n${YELLOW}[Step 4] Granting IAM Data Editor permissions to Sink Writer Identity...${NC}"
WRITER_ID=$(gcloud logging sinks describe FlowLogsSample --format='value(writerIdentity)')
echo -e "${YELLOW}[*] Writer Identity:${NC} $WRITER_ID"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="${WRITER_ID}" \
  --role="roles/bigquery.dataEditor" --quiet

echo -e "\n${YELLOW}[Step 5] Ensuring pod-2 uses podAffinity and pinging...${NC}"
REGION=$(gcloud container clusters list --filter="name=regional-demo" --format="value(location)" 2>/dev/null | head -n 1)
if [ -z "$REGION" ]; then
    REGION="us-east1"
fi
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
echo -e "${GREEN}[+] Sink FlowLogsSample & IAM permissions configured successfully!    ${NC}"
echo -e "${GREEN}[+] Click 'Check my progress' on 'Simulate Traffic' now!               ${NC}"
echo -e "${GREEN}======================================================================${NC}"
