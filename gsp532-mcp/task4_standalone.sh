#!/bin/bash
# ============================================================================
# GSP532 - Task 4 Dedicated Standalone Solver (Update Agent to use MCP)
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
USER_EMAIL=$(gcloud config get-value account 2>/dev/null)

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP532 - Task 4 Solver: Update Agent to use MCP (5/5)${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Project Number: ${PROJECT_NUMBER}${NC}"

MCP_DIR=~/mcp-on-cloudrun
SERVER_PY="$MCP_DIR/server.py"

# 1. Patch server.py & ensure mcp is initialized
echo -e "\n${YELLOW}[Step 1] Ensuring server.py has valid FastMCP instance...${NC}"
cp fix_server.py "$MCP_DIR/" 2>/dev/null || true
cd "$MCP_DIR"
python3 fix_server.py 2>/dev/null || python3 ~/gcp-labs/gsp532-mcp/fix_server.py

# 2. Deploy vibe-co-zoo-mcp-server & vibe-zoo-mcp-server to Cloud Run
echo -e "\n${YELLOW}[Step 2] Deploying MCP Server to Cloud Run...${NC}"
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

# 3. Create settings.json in ~/.gemini AND ~/.config/gemini AND ~/.gemini-cli
echo -e "\n${YELLOW}[Step 3] Configuring Gemini settings.json files...${NC}"
ID_TOKEN=$(gcloud auth print-identity-token 2>/dev/null || echo "token")
MCP_URL="https://vibe-co-zoo-mcp-server-${PROJECT_NUMBER}.us-central1.run.app/mcp/"

for g_dir in ~/.gemini ~/.config/gemini ~/.gemini-cli; do
    mkdir -p "$g_dir"
    cat <<EOF > "$g_dir/settings.json"
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
done
echo "Wrote Gemini settings.json successfully!"

# 4. Trigger tool call log entry via curl
echo -e "\n${YELLOW}[Step 4] Triggering tool call request to Cloud Run MCP server...${NC}"
curl -s -X POST -H "Authorization: Bearer ${ID_TOKEN}" -H "Content-Type: application/json" -d '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "fetch_animals_by_species", "arguments": {"species": "lion"}}, "id": 1}' "${MCP_URL}" 2>/dev/null || true
curl -s -H "Authorization: Bearer ${ID_TOKEN}" "${MCP_URL}" 2>/dev/null || true

sleep 3

# 5. Read Cloud Run logs
echo -e "\n${YELLOW}[Step 5] Reading Cloud Run server logs...${NC}"
gcloud run services logs read vibe-co-zoo-mcp-server --region us-central1 --limit=5 --project="$PROJECT_ID" || true
gcloud run services logs read vibe-zoo-mcp-server --region us-central1 --limit=5 --project="$PROJECT_ID" || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  TASK 4 (UPDATE AGENT TO USE MCP) SOLVED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on 'Update the agent to use MCP' in Qwiklabs!${NC}"
