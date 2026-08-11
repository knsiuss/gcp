#!/bin/bash
# ============================================================================
# GSP399 Task 1 Specialized Fixer Script
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID="$DEVSHELL_PROJECT_ID"
    gcloud config set project "$PROJECT_ID" --quiet
fi

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP399 - Task 1 Global Network Firewall Policy Fixer${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"

cp ~/gcp-labs/gsp399-network-security/task1_gsp399_fix.py . 2>/dev/null || true
python3 task1_gsp399_fix.py || python3 ~/gcp-labs/gsp399-network-security/task1_gsp399_fix.py

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  TASK 1 FIREWALL MIGRATION COMPLETED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on Task 1 in Qwiklabs!${NC}"
