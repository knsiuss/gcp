#!/bin/bash
# ============================================================================
# GSP532 - Task 4 Only: Update Agent to use MCP & Verify Logs
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

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
ID_TOKEN=$(gcloud auth print-identity-token 2>/dev/null || echo "")

MCP_URL="https://vibe-co-zoo-mcp-server-${PROJECT_NUMBER}.us-central1.run.app/mcp/"

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP532 - Task 4: Configure Gemini MCP Settings & Verify Logs${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Project Number: ${PROJECT_NUMBER}${NC}"
echo -e "${CYAN}[*] MCP Server URL: ${MCP_URL}${NC}"

echo -e "\n${YELLOW}[Step 1] Creating/Updating ~/.gemini/settings.json...${NC}"
mkdir -p ~/.gemini

cat <<EOF > ~/.gemini/settings.json
{
  "mcpServers": {
    "zoo-remote": {
      "httpUrl": "${MCP_URL}",
      "headers": {
        "Authorization": "Bearer ${ID_TOKEN}"
      }
    }
  },
  "selectedAuthType": "compute-default-credentials",
  "hasSeenIdeIntegrationNudge": true
}
EOF

echo "Configured ~/.gemini/settings.json successfully!"

echo -e "\n${YELLOW}[Step 2] Reading Cloud Run server logs (Task 4 verification requirement)...${NC}"
gcloud run services logs read vibe-co-zoo-mcp-server --region us-central1 --limit=5 --project="$PROJECT_ID" 2>/dev/null || \
gcloud run services logs read vibe-zoo-mcp-server --region us-central1 --limit=5 --project="$PROJECT_ID" 2>/dev/null || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  TASK 4 COMPLETED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on 'Update the agent to use MCP' in Qwiklabs!${NC}"
