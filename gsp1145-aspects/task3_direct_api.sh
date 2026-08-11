#!/bin/bash
# ============================================================================
# GSP1145 - Task 3 Direct REST API Solver for Data Catalog Tags/Aspects
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
echo -e "${BOLD}  GSP1145 - Task 3 Direct REST API Fixer${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"

python3 debug_and_solve_gsp1145.py || python3 ~/gcp-labs/gsp1145-aspects/debug_and_solve_gsp1145.py

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  REST API TAG ATTACHMENT COMPLETED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on Task 3 in Qwiklabs!${NC}"
