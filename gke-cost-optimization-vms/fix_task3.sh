#!/bin/bash
# fix_task3.sh
# Complete Task 3 with 100/100 points

set +e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}              Finalizing Task 3 (Simulate Traffic 20/20)              ${NC}"
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

echo -e "\n${YELLOW}[Step 1] Ensuring pod-1 and pod-2 (PodAffinity) are RUNNING...${NC}"

# Re-create pod-1 if missing
if ! kubectl get pod pod-1 &>/dev/null; then
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
fi

# Ensure pod-2 uses podAffinity
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

kubectl delete pod pod-2 --ignore-not-found=true
kubectl create -f pod-2.yaml

echo -e "${YELLOW}[*] Waiting for pod-1 and pod-2 to reach RUNNING status...${NC}"
for i in {1..30}; do
    STATUS1=$(kubectl get pod pod-1 -o jsonpath='{.status.phase}' 2>/dev/null)
    STATUS2=$(kubectl get pod pod-2 -o jsonpath='{.status.phase}' 2>/dev/null)
    if [ "$STATUS1" == "Running" ] && [ "$STATUS2" == "Running" ]; then
        echo -e "${GREEN}[+] Both pod-1 and pod-2 are RUNNING on the same node!${NC}"
        break
    fi
    echo -e "${YELLOW}[*] Waiting for Pods to be Running (pod-1: $STATUS1, pod-2: $STATUS2)... retry $i/30${NC}"
    sleep 3
done

echo -e "\n${YELLOW}[Step 2] Simulating inter-pod traffic (Pinging pod-2 from pod-1)...${NC}"
POD_2_IP=$(kubectl get pod pod-2 -o jsonpath='{.status.podIP}' 2>/dev/null)
if [ -n "$POD_2_IP" ]; then
    echo -e "${YELLOW}[*] Pod 2 IP: $POD_2_IP${NC}"
    kubectl exec pod-1 -- ping -c 10 "$POD_2_IP" || true
fi

echo -e "\n${YELLOW}[Step 3] Verifying Flow Logs & BigQuery dataset...${NC}"
gcloud compute networks subnets update default --region="$REGION" --enable-flow-logs --quiet || true
bq --location="$REGION" mk --dataset=true --project_id="$PROJECT_ID" us_flow_logs 2>/dev/null || true
gcloud logging sinks create FlowLogsSample \
  bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/us_flow_logs \
  --log-filter="resource.type=\"gce_subnetwork\"" --quiet 2>/dev/null || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}[+] Done! Click 'Check my progress' on 'Simulate Traffic' now!         ${NC}"
echo -e "${GREEN}======================================================================${NC}"
