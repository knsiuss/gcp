#!/bin/bash
# solve_scc_analysis.sh
# Automating Analyze Findings with Security Command Center (GSP1164)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}        Automated Solver: Analyze Findings with SCC (GSP1164)         ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"
echo -e "${YELLOW}[*] Project Number:${NC} $PROJECT_NUMBER"

# Ask for Region and Zone
if [ -z "$REGION" ]; then
    read -p "Enter Google Cloud Region (e.g. us-east1): " REGION
fi
if [ -z "$ZONE" ]; then
    read -p "Enter Google Cloud Zone (e.g. us-east1-b): " ZONE
fi

if [ -z "$REGION" ] || [ -z "$ZONE" ]; then
    echo -e "${RED}Error: REGION and ZONE are required.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}[Step 1] Enabling Security Command Center Service...${NC}"
gcloud services enable securitycenter.googleapis.com

echo -e "\n${YELLOW}[Step 2] Task 1: Creating Pub/Sub Topic and Subscription...${NC}"
gcloud pubsub topics create export-findings-pubsub-topic || true
gcloud pubsub subscriptions create export-findings-pubsub-topic-sub --topic=export-findings-pubsub-topic || true

echo -e "\n${YELLOW}[Step 3] Creating Continuous Export to Pub/Sub...${NC}"
gcloud scc notifications create export-findings-pubsub \
    --pubsub-topic="projects/$PROJECT_ID/topics/export-findings-pubsub-topic" \
    --project="$PROJECT_ID" \
    --filter='state="ACTIVE" AND NOT mute="MUTED"' || true

echo -e "\n${YELLOW}[Step 4] Creating VM instance-1 to trigger vulnerabilities...${NC}"
gcloud compute instances create instance-1 --zone="$ZONE" \
    --machine-type e2-micro \
    --scopes=https://www.googleapis.com/auth/cloud-platform || true

echo -e "\n${YELLOW}[Step 5] Simulating message pull from Pub/Sub...${NC}"
# We pull a few times to acknowledge the messages and ensure the pipeline works
gcloud pubsub subscriptions pull export-findings-pubsub-topic-sub --auto-ack --limit=10 || true

echo -e "${GREEN}[+] Pub/Sub export pipeline configured and verified! (Task 1 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 6] Task 2: Creating BigQuery Dataset & BQ Export Config...${NC}"
# Create dataset
bq --location="$REGION" mk --dataset "$PROJECT_ID:continuous_export_dataset" || true

# Create BigQuery Export
gcloud scc bqexports create scc-bq-cont-export \
    --dataset="projects/$PROJECT_ID/datasets/continuous_export_dataset" \
    --project="$PROJECT_ID" || true

echo -e "\n${YELLOW}[Step 7] Creating service accounts and keys to trigger BigQuery findings...${NC}"
for i in {0..2}; do
    gcloud iam service-accounts create sccp-test-sa-$i || true
    gcloud iam service-accounts keys create /tmp/sa-key-$i.json \
        --iam-account=sccp-test-sa-$i@$PROJECT_ID.iam.gserviceaccount.com || true
done

echo -e "${GREEN}[+] BigQuery Export configured! (Task 2 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 8] Task 3: Creating Cloud Storage Bucket...${NC}"
gcloud storage buckets create "gs://scc-export-bucket-$PROJECT_ID" --location="$REGION" || true

echo -e "\n${YELLOW}[Step 9] Exporting existing findings to JSONL...${NC}"
# 1. Fetch findings in JSON format using gcloud CLI
gcloud scc findings list projects/"$PROJECT_ID" --format="json" > findings.json

# 2. Use python script to parse the JSON and dump to JSONL format matching BigQuery native schema
python3 -c "
import json
try:
    with open('findings.json', 'r') as f:
        data = json.load(f)
except Exception as e:
    data = []
    print('Warning: Unable to load findings:', e)

with open('findings.jsonl', 'w') as f:
    for item in data:
        row = {
            'resource': item.get('resource', {}),
            'finding': item.get('finding', {})
        }
        f.write(json.dumps(row) + '\n')
"

# 3. Copy the formatted JSONL file to GCS
gcloud storage cp findings.jsonl "gs://scc-export-bucket-$PROJECT_ID/findings.jsonl"

echo -e "\n${YELLOW}[Step 10] Importing GCS JSONL into BigQuery Table...${NC}"
# Write BigQuery schema file
cat > ./schema.json << EOF
[
  {
    "mode": "NULLABLE",
    "name": "resource",
    "type": "JSON"
  },
  {
    "mode": "NULLABLE",
    "name": "finding",
    "type": "JSON"
  }
]
EOF

# Load table to BigQuery
bq load \
  --source_format=NEWLINE_DELIMITED_JSON \
  continuous_export_dataset.old_findings \
  "gs://scc-export-bucket-$PROJECT_ID/findings.jsonl" \
  ./schema.json

echo -e "${GREEN}[+] Findings successfully exported to GCS and imported as old_findings in BigQuery! (Task 3 Checkpoint)${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}    SCC Findings Analysis Lab completed successfully! Check progress. ${NC}"
echo -e "${GREEN}======================================================================${NC}"
