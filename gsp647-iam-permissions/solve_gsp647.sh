#!/bin/bash
# ============================================================================
# GSP647 - Configuring IAM Permissions with gcloud Solver
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP647 - Configuring IAM Permissions with gcloud Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"

cp ~/gcp-labs/gsp647-iam-permissions/solve_gsp647.py . 2>/dev/null || true
python3 solve_gsp647.py || python3 ~/gcp-labs/gsp647-iam-permissions/solve_gsp647.py

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP647 SOLVER EXECUTED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on all tasks in Qwiklabs!${NC}"
