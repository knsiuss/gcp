#!/bin/bash
# ============================================================================
# GSP097 - Cloud Natural Language API: Qwik Start
# 2 tasks: create API key (service account) + entity analysis request
# Usage (in the lab's Cloud Shell):
#   git clone https://github.com/knsiuss/gcp.git gcp-labs
#   cd gcp-labs/nl-api-gsp097
#   chmod +x solve_gsp097.sh
#   ./solve_gsp097.sh
# ============================================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

ACTIVE_ACCOUNT=$(gcloud auth list --format="value(account)" 2>/dev/null | head -1)
[ -n "$ACTIVE_ACCOUNT" ] && gcloud config set account "$ACTIVE_ACCOUNT" --quiet 2>/dev/null || true
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
[ -z "$PROJECT_ID" ] && PROJECT_ID="$DEVSHELL_PROJECT_ID"

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP097 - Cloud Natural Language API Qwik Start Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project: ${PROJECT_ID}${NC}"

SA_NAME="my-natlang-sa"
KEY_FILE="$HOME/key.json"
CONTENT="Michelangelo Caravaggio, Italian painter, is known for 'The Calling of Saint Matthew'."

# ============================================================================
# Task 1: Create an API key (service account + JSON credentials)
# ============================================================================
echo -e "\n${YELLOW}[Task 1] Creating service account & API key...${NC}"

export GOOGLE_CLOUD_PROJECT="$PROJECT_ID"

# Create service account (idempotent - error if exists is fine)
if gcloud iam service-accounts describe "$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" >/dev/null 2>&1; then
  echo "  Service account '$SA_NAME' already exists."
else
  gcloud iam service-accounts create "$SA_NAME" \
    --display-name "my natural language service account" --quiet
  echo -e "${GREEN}  [OK] Created service account: $SA_NAME${NC}"
fi

# Create JSON key (overwrite allowed)
gcloud iam service-accounts keys create "$KEY_FILE" \
  --iam-account "$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" --quiet
echo -e "${GREEN}  [OK] API key (credentials) written to $KEY_FILE${NC}"

export GOOGLE_APPLICATION_CREDENTIALS="$KEY_FILE"
echo -e "${GREEN}  [OK] GOOGLE_APPLICATION_CREDENTIALS set${NC}"
echo -e "\n${GREEN}  ==> Task 1 DONE. Check progress then continue.${NC}"

# ============================================================================
# Task 2: Make an entity analysis request
# ============================================================================
echo -e "\n${YELLOW}[Task 2] Running entity analysis request...${NC}"

# The lab asks to run this inside the SSH session to the provisioned VM.
# It also works directly from Cloud Shell using the service account key.
gcloud ml language analyze-entities --content="$CONTENT" > result.json
echo -e "${GREEN}  [OK] Response saved to result.json${NC}"

echo -e "\n${CYAN}----- result.json -----${NC}"
cat result.json
echo -e "${CYAN}-----------------------${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP097 SOLVER FINISHED${NC}"
echo -e "${GREEN}  Click 'Check my progress' for Task 1 and Task 2.${NC}"
echo -e "${GREEN}======================================================================${NC}"