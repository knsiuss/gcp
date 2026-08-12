#!/bin/bash
# ============================================================================
# GSP1317 - Establish VPC to VPC Connectivity using NCC Solution Execution
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
echo -e "${BOLD}  GSP1317 - Establish VPC to VPC Connectivity using NCC Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"

cp ~/gcp-labs/gsp1317-ncc-connectivity/solve_gsp1317.py . 2>/dev/null || true
python3 solve_gsp1317.py || python3 ~/gcp-labs/gsp1317-ncc-connectivity/solve_gsp1317.py

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP1317 SOLVER EXECUTED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on all tasks in Qwiklabs!${NC}"
