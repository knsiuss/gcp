#!/bin/bash
# ============================================================================
# ARC117 Task 3 Fixer Execution Script
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
echo -e "${BOLD}  ARC117 - Task 3 Aspect Fixer${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"

cp ~/gcp-labs/arc117-challenge-lab/task3_arc117_fix.py . 2>/dev/null || true
python3 task3_arc117_fix.py || python3 ~/gcp-labs/arc117-challenge-lab/task3_arc117_fix.py

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  TASK 3 ASPECT FIX COMPLETED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on Task 3 in Qwiklabs!${NC}"
