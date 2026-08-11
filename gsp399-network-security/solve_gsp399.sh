#!/bin/bash
# ============================================================================
# GSP399 - Design and Implement Network Security in Google Cloud: Challenge Lab
# Automated Solution Script
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

ACTIVE_ACCOUNT=$(gcloud auth list --format="value(account)" 2>/dev/null | head -1)
if [ -n "$ACTIVE_ACCOUNT" ]; then
    gcloud config set account "$ACTIVE_ACCOUNT" --quiet 2>/dev/null || true
fi

if [ -n "$DEVSHELL_PROJECT_ID" ]; then
    gcloud config set project "$DEVSHELL_PROJECT_ID" --quiet 2>/dev/null || true
fi

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP399 - Network Security Challenge Lab Automated Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Active Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"

cp ~/gcp-labs/gsp399-network-security/solve_gsp399.py . 2>/dev/null || true
python3 solve_gsp399.py || python3 ~/gcp-labs/gsp399-network-security/solve_gsp399.py

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP399 SOLVER EXECUTED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on all tasks in Qwiklabs!${NC}"
