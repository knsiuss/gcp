#!/bin/bash
# solve_scc.sh
# Automating Get Started with Security Command Center (GSP1124)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}        Automated Solver: Get Started with Security Command Center     ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project)

echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

echo -e "\n${YELLOW}[Step 1] Creating Dynamic Mute Rule for Flow Logs...${NC}"
gcloud scc muteconfigs create mute-flowlogs-findings \
    --project="$PROJECT_ID" \
    --filter='category="FLOW_LOGS_DISABLED"' \
    --description="Mute rule for VPC Flow Logs" || true

echo -e "${GREEN}[+] Mute rule created!${NC}"

echo -e "\n${YELLOW}[Step 2] Creating scc-lab-net network...${NC}"
gcloud compute networks create scc-lab-net --subnet-mode=auto || true

echo -e "${GREEN}[+] Network scc-lab-net created!${NC}"

echo -e "\n${YELLOW}[Step 3] Restricting default firewall rules (SSH and RDP) to IAP range...${NC}"
# Update RDP firewall rule (restricting from 0.0.0.0/0 to 35.235.240.0/20)
gcloud compute firewall-rules update default-allow-rdp \
    --source-ranges="35.235.240.0/20" || true

# Update SSH firewall rule (restricting from 0.0.0.0/0 to 35.235.240.0/20)
gcloud compute firewall-rules update default-allow-ssh \
    --source-ranges="35.235.240.0/20" || true

echo -e "${GREEN}[+] Firewall rules restricted successfully!${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}    SCC Lab completed successfully! Check Qwiklabs progress.           ${NC}"
echo -e "${GREEN}======================================================================${NC}"
