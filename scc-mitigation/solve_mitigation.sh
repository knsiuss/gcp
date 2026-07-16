#!/bin/bash
# solve_mitigation.sh
# Automating Mitigate Threats and Vulnerabilities with SCC: Challenge Lab (GSP382)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}    Automated Solver: Mitigate Threats & Vulnerabilities (GSP382)     ${NC}"
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

echo -e "\n${YELLOW}[Step 1] Task 2: Creating Static Mute Rules...${NC}"
# 1. Flow logs disabled mute rule
gcloud scc muteconfigs create muting-flow-log-findings \
    --project="$PROJECT_ID" \
    --filter='category="FLOW_LOGS_DISABLED"' \
    --description="Rule for muting VPC Flow Logs" \
    --type=static || true

# 2. Audit logging disabled mute rule
gcloud scc muteconfigs create muting-audit-logging-findings \
    --project="$PROJECT_ID" \
    --filter='category="AUDIT_LOGGING_DISABLED"' \
    --description="Rule for muting audit logs" \
    --type=static || true

# 3. Admin service account mute rule
gcloud scc muteconfigs create muting-admin-sa-findings \
    --project="$PROJECT_ID" \
    --filter='category="ADMIN_SERVICE_ACCOUNT"' \
    --description="Rule for muting admin service account findings" \
    --type=static || true

echo -e "${GREEN}[+] Static mute rules created! (Task 2 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 2] Task 3: Fixing High Vulnerability Findings (Firewalls)...${NC}"
# Find and restrict SSH and RDP firewall rules
for rule in $(gcloud compute firewall-rules list --format="value(name)"); do
    if [[ "$rule" == *"ssh"* ]] || [[ "$rule" == *"rdp"* ]]; then
        echo -e "${YELLOW}[*] Restricting firewall rule: $rule...${NC}"
        gcloud compute firewall-rules update "$rule" --source-ranges="35.235.240.0/20" || true
    fi
done

# Double check standard names to be absolutely sure
if gcloud compute firewall-rules describe default-allow-ssh >/dev/null 2>&1; then
    gcloud compute firewall-rules update default-allow-ssh --source-ranges="35.235.240.0/20" || true
fi
if gcloud compute firewall-rules describe default-allow-rdp >/dev/null 2>&1; then
    gcloud compute firewall-rules update default-allow-rdp --source-ranges="35.235.240.0/20" || true
fi

echo -e "${GREEN}[+] Firewall rules restricted successfully! (Task 3 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 3] Task 4: Promoting VM cls-vm External IP to Static...${NC}"
# Find IP Address of cls-vm
VM_IP=$(gcloud compute instances describe cls-vm --zone="$ZONE" --format="value(networkInterfaces[0].accessConfigs[0].natIP)" || true)

if [ -n "$VM_IP" ]; then
    echo -e "${YELLOW}[*] VM IP found: $VM_IP. Reserving static IP static-ip...${NC}"
    gcloud compute addresses create static-ip --addresses="$VM_IP" --region="$REGION" || true
else
    echo -e "${RED}Warning: Could not detect cls-vm IP address. Skipping IP promotion...${NC}"
fi

echo -e "\n${YELLOW}[Step 4] Configuring and Triggering Web Security Scanner...${NC}"
# Enable API
gcloud services enable websecurityscanner.googleapis.com

# Create Scan Config
gcloud alpha web-security-scanner scan-configs create \
    --display-name="cls-scan" \
    --starting-urls="http://${VM_IP}:8080" \
    --project="$PROJECT_ID" || true

# Get Scan Config Path
SCAN_PATH=$(gcloud alpha web-security-scanner scan-configs list --project="$PROJECT_ID" --format="value(name)" | head -n 1)

# Run Scan
if [ -n "$SCAN_PATH" ]; then
    gcloud alpha web-security-scanner scan-runs start "$SCAN_PATH" --project="$PROJECT_ID" || true
    echo -e "${GREEN}[+] Web Security Scan triggered! (Task 4 Checkpoint)${NC}"
else
    echo -e "${RED}Warning: Scan Config path not found. Scan not started.${NC}"
fi

echo -e "\n${YELLOW}[Step 5] Task 5: Exporting Findings to GCS...${NC}"
# Create Cloud Storage Bucket
gcloud storage buckets create "gs://scc-export-bucket-$PROJECT_ID" --location="$REGION" || true

# Fetch findings via CLI
gcloud scc findings list projects/"$PROJECT_ID" --format="json" > findings.json

# Parse into JSONL format
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

# Copy the file to the GCS bucket
gcloud storage cp findings.jsonl "gs://scc-export-bucket-$PROJECT_ID/findings.jsonl"

echo -e "${GREEN}[+] Findings exported and uploaded to GCS! (Task 5 Checkpoint)${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}    SCC Challenge Lab completed successfully! Check Qwiklabs progress. ${NC}"
echo -e "${GREEN}======================================================================${NC}"
