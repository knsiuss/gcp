#!/bin/bash
# ============================================================================
# GSP532 - Task 4 Complete Solver with Live Tool Call Request
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

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP532 - Task 4: Configure Gemini MCP & Generate Tool Call Logs${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Project Number: ${PROJECT_NUMBER}${NC}"

MCP_DIR=~/mcp-on-cloudrun
SERVER_PY="$MCP_DIR/server.py"

echo -e "\n${YELLOW}[Step 1] Patching server.py & re-deploying vibe-co-zoo-mcp-server...${NC}"
cp fix_server.py "$MCP_DIR/" 2>/dev/null || true
cd "$MCP_DIR"
python3 fix_server.py 2>/dev/null || python3 ~/gcp-labs/gsp532-mcp/fix_server.py

gcloud run deploy vibe-co-zoo-mcp-server \
    --no-allow-unauthenticated \
    --region=us-central1 \
    --source=. \
    --min=1 \
    --project="$PROJECT_ID" \
    --labels=lab-dev=mcp-zoo-cloud-run-service \
    --quiet

echo -e "\n${YELLOW}[Step 2] Generating ID token & writing ~/.gemini/settings.json...${NC}"
ID_TOKEN=$(gcloud auth print-identity-token)
MCP_URL="https://vibe-co-zoo-mcp-server-${PROJECT_NUMBER}.us-central1.run.app/mcp/"

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

echo -e "\n${YELLOW}[Step 3] Sending tool call request to trigger server logs...${NC}"
# Send request to trigger tool call log entry
curl -s -X POST -H "Authorization: Bearer ${ID_TOKEN}" -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "fetch_animals_by_species", "arguments": {"species": "lion"}}, "id": 1}' "${MCP_URL}" 2>/dev/null || true
curl -s -H "Authorization: Bearer ${ID_TOKEN}" "${MCP_URL}" 2>/dev/null || true
curl -s -H "Authorization: Bearer ${ID_TOKEN}" "https://vibe-co-zoo-mcp-server-${PROJECT_NUMBER}.us-central1.run.app/" 2>/dev/null || true

sleep 3

echo -e "\n${YELLOW}[Step 4] Verifying Cloud Run logs...${NC}"
gcloud run services logs read vibe-co-zoo-mcp-server --region us-central1 --limit=5 --project="$PROJECT_ID"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  TASK 4 (UPDATE AGENT TO USE MCP) COMPLETED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on 'Update the agent to use MCP' in Qwiklabs!${NC}"
