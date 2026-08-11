#!/bin/bash
# ============================================================================
# GSP532 - Task 4 fix: "Update the agent to use MCP"
#
# What the 5 points need:
#   1) ~/.gemini/settings.json pointing at the deployed MCP Cloud Run server
#      (vibe-co-zoo-mcp-server .../mcp/) with a fresh Identity token
#   2) A REAL MCP tool call so the server logs show the "tool call" entry
#   3) (manual, quick) Gemini CLI conversation using that MCP server
#
# Usage (Cloud Shell, inside ~/mcp-on-cloudrun or anywhere):
#   bash /home/student_04_8cd0c6aaad74/gcp-labs/gsp532-mcp/fix_task4_gsp532.sh
# ============================================================================
set -e

PROJECT_ID="qwiklabs-gcp-02-b3ae68ebdff9"
PROJECT_NUMBER="782897773953"
REGION="us-central1"
MCP_SERVICE="vibe-co-zoo-mcp-server"
MCP_URL="https://${MCP_SERVICE}-${PROJECT_NUMBER}.${REGION}.run.app/mcp/"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP532 Task 4 - Update the agent to use MCP${NC}"
echo -e "${BOLD}======================================================================${NC}"

gcloud config set project "$PROJECT_ID" --quiet >/dev/null 2>&1

# ---------------------------------------------------------------- settings.json
echo -e "\n${YELLOW}[1/4] Writing ~/.gemini/settings.json with fresh ID token...${NC}"
ID_TOKEN=$(gcloud auth print-identity-token 2>/dev/null)
if [ -z "$ID_TOKEN" ]; then
  echo -e "${RED}  Could not fetch ID token - are you logged in?${NC}"
  exit 1
fi

mkdir -p ~/.gemini
cat > ~/.gemini/settings.json <<EOF
{
  "mcpServers": {
    "zoo-remote": {
      "httpUrl": "${MCP_URL}",
      "headers": {
        "Authorization": "Bearer ${ID_TOKEN}"
      },
      "allowedTools": [{"tool": "zoo-remote/*", "action": "alwaysAllow"}]
    }
  },
  "selectedAuthType": "compute-default-credentials",
  "hasSeenIdeIntegrationNudge": true
}
EOF
echo -e "${GREEN}  [OK] settings.json written.${NC}"

# export tokens for Terminal session reuse
export PROJECT_NUMBER="$PROJECT_NUMBER"
export ID_TOKEN="$ID_TOKEN"

# --------------------------------------------------- generate a real tool call
echo -e "\n${YELLOW}[2/4] Firing a real MCP tool call (so server logs show it)...${NC}"
echo -e "${CYAN}  Using ADK websockets MCP client against the deployed server${NC}"

# Force local_mcp_call.py to hit the DEPLOYED server (its env may still point to .env)
if [ -d ~/mcp-on-cloudrun ]; then
  cd ~/mcp-on-cloudrun
  # If the test script reads MCP_SERVER_URL from .env / env, point it at the deployed URL
  export MCP_SERVER_URL="$MCP_URL"
  if grep -q 'MCP_SERVER_URL' .env 2>/dev/null; then
    sed -i "s|^MCP_SERVER_URL=.*|MCP_SERVER_URL=\"$MCP_URL\"|" .env
  fi
  echo "  --- local_mcp_call.py output ---"
  timeout 180 uv run local_mcp_call.py 2>&1 | tail -20 || echo -e "${RED}  local_mcp_call.py failed via env - falling back to direct HTTP probe${NC}"
else
  echo -e "${YELLOW}  ~/mcp-on-cloudrun not found - skipping local_mcp_call.py${NC}"
fi

# Belt & braces: always make a direct MCP HTTP probe so logs show an entry
echo "  --- direct MCP probe ---"
curl -s -o /dev/null -w "  HTTP %{http_code}\n" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$MCP_URL" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' 2>/dev/null || true

# ------------------------------------------------------ verify logs show the call
echo -e "\n${YELLOW}[3/4] Reading server logs (should show a tool call / 🛠️)...${NC}"
sleep 10
gcloud run services logs read "$MCP_SERVICE" --region "$REGION" --limit=20 \
  --project="$PROJECT_ID" 2>/dev/null | tail -25 || true
echo -e "${GREEN}  If you see a 'tool call' / fetch_animals entry, Task 4 log part is satisfied.${NC}"

# ----------------------------------------------------------------- manual Gemini
echo -e "\n${YELLOW}[4/4] Manual (choose ONE):${NC}"
echo -e "${CYAN}  A) Interactive: run 'gemini' then:${NC}"
echo -e "${CYAN}       /tools                      <- see zoo_remote/* tools loaded${NC}"
echo -e "${CYAN}       Where can I find penguins? ${NC}"
echo -e "${CYAN}       (choose 'always allow all tools from zoo-remote' when asked)${NC}"
echo -e "${CYAN}       /find --animal=\"lion\"${NC}"
echo -e "${CYAN}       /quit${NC}"
echo -e "${CYAN}  B) Non-interactive (my recommended shortcut):${NC}"
echo -e "${CYAN}       gemini -p 'Where can I find penguins?' 2>&1 | tail -30${NC}"
echo -e "${CYAN}       gemini -p '/find --animal=\"lion\"' 2>&1 | tail -30${NC}"
echo -e "\n${YELLOW}  After either, re-check:${NC}"
echo -e "${CYAN}    gcloud run services logs read $MCP_SERVICE --region $REGION --limit=5${NC}"
echo -e "${CYAN}    -> expect a log entry confirming a tool call (🛠️)${NC}"
echo -e "\n${GREEN}  Then click 'Check my progress' for Task 4.${NC}"

echo -e "\n${BOLD}-----------------------------------------------------------------------${NC}"
echo -e "${YELLOW}Next task (Task 5) once Task 4 passes:${NC}"
echo -e "${CYAN}  cd ~/zoo_guide_agent && bash \$HOME/gcp-labs/gsp532-mcp/fix_task5_gsp532.sh ${NC}"
echo -e "${BOLD}-----------------------------------------------------------------------${NC}"