#!/bin/bash
# ============================================================================
# GSP1145 - Task 3 Dataplex 2.0 Aspect Attacher (Bypasses Data Catalog Deprecation)
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
echo -e "${BOLD}  GSP1145 - Task 3 Dataplex 2.0 Aspect Attacher${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"

cp ~/gcp-labs/gsp1145-aspects/solve_dataplex_aspects.py . 2>/dev/null || true
python3 solve_dataplex_aspects.py || python3 ~/gcp-labs/gsp1145-aspects/solve_dataplex_aspects.py

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  DATAPLEX ASPECT ATTACHMENT COMPLETED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on Task 3 in Qwiklabs!${NC}"
