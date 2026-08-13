#!/bin/bash
# ============================================================================
# GSP1048 - Cloud Spanner - Database Fundamentals Solver
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP1048 - Cloud Spanner - Database Fundamentals Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID="$DEVSHELL_PROJECT_ID"
fi

echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"

cp ~/gcp-labs/gsp1048-spanner-fundamentals/solve_gsp1048.py . 2>/dev/null || true
python3 solve_gsp1048.py || python3 ~/gcp-labs/gsp1048-spanner-fundamentals/solve_gsp1048.py

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP1048 SOLVER EXECUTED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on all tasks in Qwiklabs!${NC}"
