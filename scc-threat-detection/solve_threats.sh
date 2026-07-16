#!/bin/bash
# solve_threats.sh
# Automating Detect and Investigate Threats with SCC (GSP1125)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}    Automated Solver: Detect & Investigate Threats with SCC (GSP1125) ${NC}"
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

echo -e "\n${YELLOW}[Step 1] Enabling Security Command Center API...${NC}"
gcloud services enable securitycenter.googleapis.com

echo -e "\n${YELLOW}[Step 2] Task 1: Granting BigQuery Admin role to external user...${NC}"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="user:demouser1@gmail.com" \
    --role="roles/bigquery.admin"

echo -e "${YELLOW}[*] Demouser1 added. Simulating persistence detection. Sleeping for 10 seconds...${NC}"
sleep 10

echo -e "\n${YELLOW}[Step 3] Removing BigQuery Admin role from external user (Mitigating Threat)...${NC}"
gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
    --member="user:demouser1@gmail.com" \
    --role="roles/bigquery.admin"

echo -e "${GREEN}[+] Task 1 Complete! (Check progress on Qwiklabs)${NC}"

echo -e "\n${YELLOW}[Step 4] Task 2: Enabling Resource Manager Admin Read Audit Logs...${NC}"
# Fetch current IAM policy
gcloud projects get-iam-policy "$PROJECT_ID" --format="json" > policy.json

# Use Python to programmatically inject the Cloud Resource Manager API Admin Read audit configuration
python3 -c "
import json
with open('policy.json', 'r') as f:
    policy = json.load(f)

audit_configs = policy.get('auditConfigs', [])
found = False

for config in audit_configs:
    if config.get('service') == 'resourcemanager.googleapis.com':
        found = True
        configs = config.get('auditLogConfigs', [])
        has_admin_read = any(c.get('logType') == 'ADMIN_READ' for c in configs)
        if not has_admin_read:
            configs.append({'logType': 'ADMIN_READ'})
        config['auditLogConfigs'] = configs

if not found:
    audit_configs.append({
        'auditLogConfigs': [{'logType': 'ADMIN_READ'}],
        'service': 'resourcemanager.googleapis.com'
    })

policy['auditConfigs'] = audit_configs

with open('policy.json', 'w') as f:
    json.dump(policy, f)
"

# Set the updated IAM policy back
gcloud projects set-iam-policy "$PROJECT_ID" policy.json

echo -e "${GREEN}[+] Audit logs for Resource Manager enabled!${NC}"

echo -e "\n${YELLOW}[Step 5] Creating VM instance-1 with default service account...${NC}"
gcloud compute instances create instance-1 --zone="$ZONE" \
    --machine-type=e2-micro \
    --scopes=https://www.googleapis.com/auth/cloud-platform --quiet || true

echo -e "\n${YELLOW}[Step 6] Waiting for VM instance to start and SSH to become ready...${NC}"
# We poll the VM SSH port using a lightweight command until it succeeds
for i in {1..15}; do
    if gcloud compute ssh instance-1 --zone="$ZONE" --command="echo SSH_READY" --quiet --tunnel-through-iap 2>/dev/null; then
        echo -e "${GREEN}[+] SSH is ready!${NC}"
        break
    fi
    echo -e "${YELLOW}[*] Still waiting... ($((i * 10))s)${NC}"
    sleep 10
done

echo -e "\n${YELLOW}[Step 7] Simulating Service Account Self-Investigation inside VM...${NC}"
gcloud compute ssh instance-1 --zone="$ZONE" \
    --command="gcloud projects get-iam-policy \$(gcloud config get project)" --quiet --tunnel-through-iap

echo -e "${GREEN}[+] Self-investigation triggered! (Task 2 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 8] Task 3: Creating DNS Server Policy with logging enabled...${NC}"
gcloud dns policies create dns-test-policy \
    --networks=default \
    --enable-logging || true

echo -e "${GREEN}[+] DNS Server policy created!${NC}"

echo -e "\n${YELLOW}[Step 9] Simulating Malware Bad Domain connection inside VM...${NC}"
gcloud compute ssh instance-1 --zone="$ZONE" \
    --command="curl etd-malware-trigger.goog" --quiet --tunnel-through-iap

echo -e "${GREEN}[+] Malware bad domain query triggered!${NC}"

echo -e "\n${YELLOW}[Step 10] Deleting VM instance-1 to clean up environment...${NC}"
gcloud compute instances delete instance-1 --zone="$ZONE" --quiet

echo -e "${GREEN}[+] VM instance-1 deleted! (Task 3 Checkpoint)${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}    SCC Threat Detection Lab completed successfully! Check progress.  ${NC}"
echo -e "${GREEN}======================================================================${NC}"
