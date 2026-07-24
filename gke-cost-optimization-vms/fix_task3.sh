#!/bin/bash
# fix_task3.sh
# Fix FlowLogsSample sink for Qwiklabs check

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

echo -e "\n${YELLOW}[Step 1] Creating BigQuery dataset 'us_flow_logs'...${NC}"
bq --location=us-east1 mk --dataset ${PROJECT_ID}:us_flow_logs 2>/dev/null || true
bq --location="$REGION" mk --dataset=true --project_id="$PROJECT_ID" us_flow_logs 2>/dev/null || true

echo -e "\n${YELLOW}[Step 2] Re-creating Logging Sink 'FlowLogsSample'...${NC}"
gcloud logging sinks delete FlowLogsSample --quiet 2>/dev/null || true

gcloud logging sinks create FlowLogsSample \
  bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/us_flow_logs \
  --log-filter="logName=\"projects/${PROJECT_ID}/logs/compute.googleapis.com%2Fvpc_flows\"" --quiet

echo -e "\n${YELLOW}[Step 3] Describing created sink 'FlowLogsSample':${NC}"
gcloud logging sinks describe FlowLogsSample

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}[+] Sink 'FlowLogsSample' created successfully!                        ${NC}"
echo -e "${GREEN}[+] Click 'Check my progress' on 'Simulate Traffic' now!               ${NC}"
echo -e "${GREEN}======================================================================${NC}"
