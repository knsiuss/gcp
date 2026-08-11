#!/bin/bash
# ============================================================================
# ARC117 Task 3 Zone Entry Aspect Attacher (gcloud alpha dataplex)
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
echo -e "${BOLD}  ARC117 - Task 3 Zone Entry Aspect Attacher${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"

cp ~/gcp-labs/arc117-challenge-lab/test_zone_entry.py . 2>/dev/null || true
python3 test_zone_entry.py || python3 ~/gcp-labs/arc117-challenge-lab/test_zone_entry.py

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  TASK 3 ZONE ASPECT COMPLETED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on Task 3 in Qwiklabs!${NC}"
