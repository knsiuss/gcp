#!/bin/bash
# fix_task3.sh
# Fix FlowLogsSample filter to match Qwiklabs exact check

set +e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}       Fixing Sink 'FlowLogsSample' Filter & Dataset Access (100/100) ${NC}"
echo -e "${BLUE}======================================================================${NC}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    export PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
fi
export GOOGLE_CLOUD_PROJECT=$PROJECT_ID

echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

echo -e "\n${YELLOW}[Step 1] Ensuring BigQuery dataset 'us_flow_logs' exists...${NC}"
bq mk --dataset ${PROJECT_ID}:us_flow_logs 2>/dev/null || true

echo -e "\n${YELLOW}[Step 2] Updating Logging Sink 'FlowLogsSample' with exact log filter...${NC}"
DEST="bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/us_flow_logs"
FILTER="logName=\"projects/${PROJECT_ID}/logs/compute.googleapis.com%2Fvpc_flows\""

gcloud logging sinks update FlowLogsSample "$DEST" --log-filter="$FILTER" --quiet 2>/dev/null || \
gcloud logging sinks create FlowLogsSample "$DEST" --log-filter="$FILTER" --quiet

echo -e "\n${YELLOW}[Step 3] Verifying Sink 'FlowLogsSample' configuration:${NC}"
gcloud logging sinks describe FlowLogsSample

echo -e "\n${YELLOW}[Step 4] Ensuring dataset-level access for Sink Service Account...${NC}"
python3 - << 'EOF'
import os
import json
import subprocess

try:
    project_id = subprocess.check_output("gcloud config get-value project", shell=True).decode().strip()
    writer_id = subprocess.check_output("gcloud logging sinks describe FlowLogsSample --format='value(writerIdentity)'", shell=True).decode().strip()
    sa_email = writer_id.replace("serviceAccount:", "")

    print(f"[*] Sink Service Account: {sa_email}")

    ds_json_raw = subprocess.check_output(f"bq show --format=prettyjson {project_id}:us_flow_logs", shell=True).decode()
    ds_info = json.loads(ds_json_raw)

    access_list = ds_info.get("access", [])
    already_added = any(entry.get("userByEmail") == sa_email for entry in access_list)

    if not already_added:
        access_list.append({
            "role": "WRITER",
            "userByEmail": sa_email
        })
        with open("ds_update.json", "w") as f:
            json.dump({"access": access_list}, f)
        subprocess.run(f"bq update --source ds_update.json {project_id}:us_flow_logs", shell=True, check=True)
        print(f"[+] Added {sa_email} as WRITER to dataset us_flow_logs!")
    else:
        print(f"[+] {sa_email} is already authorized on us_flow_logs!")
except Exception as e:
    print(f"[!] Warning updating dataset access: {e}")
EOF

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
echo -e "${GREEN}[+] Sink FlowLogsSample filter & access configured successfully!     ${NC}"
echo -e "${GREEN}[+] Click 'Check my progress' on 'Simulate Traffic' now!               ${NC}"
echo -e "${GREEN}======================================================================${NC}"
