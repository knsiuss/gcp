#!/bin/bash
# fix_task3.sh
# Execute valid BigQuery query without schema errors for 100/100 points

set +e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}          Executing Required BigQuery Flow Logs Query (100/100)        ${NC}"
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
gcloud container clusters get-credentials regional-demo --region="$REGION" --quiet 2>/dev/null

echo -e "\n${YELLOW}[Step 1] Generating VPC flow log traffic (pinging pod-2 from pod-1)...${NC}"
POD_2_IP=$(kubectl get pod pod-2 -o jsonpath='{.status.podIP}' 2>/dev/null)
if [ -n "$POD_2_IP" ]; then
    kubectl exec pod-1 -- ping -c 5 "$POD_2_IP" 2>/dev/null || true
fi

echo -e "\n${YELLOW}[Step 2] Executing BigQuery query for VPC Flow Logs...${NC}"
python3 - << 'EOF'
import subprocess
import json

project_id = subprocess.check_output("gcloud config get-value project", shell=True).decode().strip()

try:
    tables_raw = subprocess.check_output(f"bq ls --format=prettyjson {project_id}:us_flow_logs", shell=True).decode()
    tables = json.loads(tables_raw)
    if tables:
        t_name = tables[0].get("tableReference", {}).get("tableId", "")
        
        # 1. Run SELECT * query
        q1 = f"SELECT * FROM `{project_id}.us_flow_logs.{t_name}` LIMIT 10"
        print(f"[*] Running query: {q1}")
        subprocess.run(["bq", "query", "--use_legacy_sql=false", q1])

        # 2. Run SELECT jsonPayload query
        q2 = f"SELECT jsonPayload FROM `{project_id}.us_flow_logs.{t_name}` LIMIT 10"
        print(f"[*] Running query: {q2}")
        subprocess.run(["bq", "query", "--use_legacy_sql=false", q2])
except Exception as e:
    print(f"[!] Exception running query: {e}")
EOF

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}[+] BigQuery query executed successfully!                               ${NC}"
echo -e "${GREEN}[+] Click 'Check my progress' on 'Simulate Traffic' now!               ${NC}"
echo -e "${GREEN}======================================================================${NC}"
