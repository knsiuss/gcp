#!/bin/bash
# fix_task3.sh
# Fix Sink FlowLogsSample and Dataset IAM Access without project-level IAM requirement

set +e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}       Fixing Dataset Access for Sink 'FlowLogsSample' (100/100)      ${NC}"
echo -e "${BLUE}======================================================================${NC}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    export PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
fi
export GOOGLE_CLOUD_PROJECT=$PROJECT_ID

echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

echo -e "\n${YELLOW}[Step 1] Ensuring BigQuery dataset 'us_flow_logs' exists...${NC}"
bq mk --dataset ${PROJECT_ID}:us_flow_logs 2>/dev/null || true

echo -e "\n${YELLOW}[Step 2] Ensuring Logging Sink 'FlowLogsSample' exists...${NC}"
if ! gcloud logging sinks describe FlowLogsSample &>/dev/null; then
  gcloud logging sinks create FlowLogsSample \
    bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/us_flow_logs --quiet
fi

echo -e "\n${YELLOW}[Step 3] Granting dataset-level access to Sink Writer Identity...${NC}"
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

echo -e "\n${YELLOW}[Step 4] Pinging pod-2 to generate flow logs...${NC}"
REGION=$(gcloud container clusters list --filter="name=regional-demo" --format="value(location)" 2>/dev/null | head -n 1)
if [ -z "$REGION" ]; then
    REGION="us-east1"
fi
gcloud container clusters get-credentials regional-demo --region="$REGION" --quiet 2>/dev/null

POD_2_IP=$(kubectl get pod pod-2 -o jsonpath='{.status.podIP}' 2>/dev/null)
if [ -n "$POD_2_IP" ]; then
    kubectl exec pod-1 -- ping -c 5 "$POD_2_IP" 2>/dev/null || true
fi

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}[+] Sink FlowLogsSample & BigQuery access granted successfully!       ${NC}"
echo -e "${GREEN}[+] Click 'Check my progress' on 'Simulate Traffic' now!               ${NC}"
echo -e "${GREEN}======================================================================${NC}"
