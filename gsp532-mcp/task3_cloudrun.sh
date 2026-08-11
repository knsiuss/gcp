#!/bin/bash
# ============================================================================
# GSP532 - Task 3 Part 2: Deploy MCP Server to Cloud Run
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
echo -e "${BOLD}  GSP532 - Task 3: Deploy Fixed MCP Server to Cloud Run${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"

MCP_DIR=~/mcp-on-cloudrun

echo -e "\n${YELLOW}[Step 1] Ensuring ~/mcp-on-cloudrun/server.py is properly patched...${NC}"
cp fix_server.py ~/mcp-on-cloudrun/ 2>/dev/null || true
cd "$MCP_DIR"
python3 fix_server.py 2>/dev/null || python3 ~/gcp-labs/gsp532-mcp/fix_server.py

echo -e "\n${YELLOW}[Step 2] Re-deploying vibe-co-zoo-mcp-server to Cloud Run...${NC}"
gcloud run deploy vibe-co-zoo-mcp-server \
    --no-allow-unauthenticated \
    --region=us-central1 \
    --source=. \
    --min=1 \
    --project="$PROJECT_ID" \
    --labels=lab-dev=mcp-zoo-cloud-run-service \
    --quiet

gcloud run deploy vibe-zoo-mcp-server \
    --no-allow-unauthenticated \
    --region=us-central1 \
    --source=. \
    --min=1 \
    --project="$PROJECT_ID" \
    --labels=lab-dev=mcp-zoo-cloud-run-service \
    --quiet 2>/dev/null || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  MCP CLOUD RUN DEPLOYMENT COMPLETED CLEANLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on 'MCP deploy to Cloud Run' and Task 4 in Qwiklabs!${NC}"
