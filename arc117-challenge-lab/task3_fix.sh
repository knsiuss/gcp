#!/bin/bash
# ============================================================================
# ARC117 Task 3 Entry Group Discovery & Aspect Attacher
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
echo -e "${BOLD}  ARC117 - Task 3 Entry Group Discovery & Aspect Attacher${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"

cp ~/gcp-labs/arc117-challenge-lab/find_entry_groups.py . 2>/dev/null || true
python3 find_entry_groups.py || python3 ~/gcp-labs/arc117-challenge-lab/find_entry_groups.py

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  TASK 3 ENTRY GROUP DISCOVERY SOLVED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on Task 3 in Qwiklabs!${NC}"
