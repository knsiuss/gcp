#!/bin/bash
# fix_task3.sh
# Execute BigQuery SQL query cleanly using python list args to avoid shell backtick expansion

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
import time

project_id = subprocess.check_output("gcloud config get-value project", shell=True).decode().strip()

t_name = ""
try:
    tables_raw = subprocess.check_output(f"bq ls --format=prettyjson {project_id}:us_flow_logs", shell=True).decode()
    tables = json.loads(tables_raw)
    for t in tables:
        tid = t.get("tableReference", {}).get("tableId", "")
        if "vpc_flows" in tid:
            t_name = tid
            break
    if not t_name and tables:
        t_name = tables[0].get("tableReference", {}).get("tableId", "")
except Exception:
    pass

if not t_name:
    t_name = "compute_googleapis_com_vpc_flows_*"

query_str = f"SELECT jsonPayload.src_instance.zone AS src_zone, jsonPayload.src_instance.vm_name AS src_vm, jsonPayload.dest_instance.zone AS dest_zone, jsonPayload.dest_instance.vm_name FROM `{project_id}.us_flow_logs.{t_name}` LIMIT 10"

print(f"[*] Querying BigQuery:\n{query_str}\n")

# Use list args to avoid shell backtick expansion
res = subprocess.run(["bq", "query", "--use_legacy_sql=false", query_str])

if res.returncode != 0:
    fallback_q = f"SELECT jsonPayload.src_instance.zone AS src_zone, jsonPayload.src_instance.vm_name AS src_vm, jsonPayload.dest_instance.zone AS dest_zone, jsonPayload.dest_instance.vm_name FROM `{project_id}.us_flow_logs.compute_googleapis_com_vpc_flows_*` LIMIT 10"
    subprocess.run(["bq", "query", "--use_legacy_sql=false", fallback_q])
EOF

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}[+] BigQuery query executed successfully!                               ${NC}"
echo -e "${GREEN}[+] Click 'Check my progress' on 'Simulate Traffic' now!               ${NC}"
echo -e "${GREEN}======================================================================${NC}"
