#!/bin/bash
# ============================================================================
# GSP532 - Task 5 Part 2: Deploy ADK Agent to Cloud Run
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
echo -e "${BOLD}  GSP532 - Task 5: Deploy ADK Tour Guide Agent to Cloud Run${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"

export PATH=$PATH:"/home/${USER}/.local/bin"
ZOO_DIR=~/zoo_guide_agent

cd "$ZOO_DIR"
source .venv/bin/activate 2>/dev/null || true

echo -e "\n${YELLOW}[Step 1] Deploying vibe-co-zoo-tour-guide to Cloud Run...${NC}"
adk deploy cloud_run \
  --project="$PROJECT_ID" \
  --region=us-central1 \
  --service_name=vibe-co-zoo-tour-guide \
  --with_ui \
  . \
  -- \
  --labels=lab-dev=cloud-zoo-run-adk-service \
  --quiet

adk deploy cloud_run \
  --project="$PROJECT_ID" \
  --region=us-central1 \
  --service_name=vibe-zoo-tour-guide \
  --with_ui \
  . \
  -- \
  --labels=lab-dev=cloud-zoo-run-adk-service \
  --quiet 2>/dev/null || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  ADK AGENT CLOUD RUN DEPLOYMENT COMPLETED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on 'Deploy the ADK Agent on Cloud Run' in Qwiklabs!${NC}"
