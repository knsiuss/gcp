#!/bin/bash
# ============================================================================
# GSP532 - Task 5 fix: Dockerize + deploy ADK Agent to Cloud Run
#
# Score shown: "Deploy the ADK Agent locally" 0/20, "on Cloud Run" 0/10,
# "Verify deployed ADK Agent" 0/10. And the checkpoint message was:
#   "Please deploy the ADK Agent on Cloud Run as instructed."
#
# This script:
#   1) Completes TODO edits in ~/zoo_guide_agent/agent.py
#   2) Installs the package in a venv
#   3) Runs 'adk web' locally (Task "Deploy the ADK Agent locally")
#   4) Deploys vibe-co-zoo-tour-guide to Cloud Run with --with_ui
#
# Usage (Cloud Shell):
#   bash $HOME/gcp-labs/gsp532-mcp/fix_task5_gsp532.sh
# ============================================================================
set -e

PROJECT_ID="qwiklabs-gcp-02-b3ae68ebdff9"
PROJECT_NUMBER="782897773953"
REGION="us-central1"
ADK_SERVICE="vibe-co-zoo-tour-guide"
MCP_SERVICE="vibe-co-zoo-mcp-server"
MCP_URL="https://${MCP_SERVICE}-${PROJECT_NUMBER}.${REGION}.run.app/mcp/"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP532 Task 5 - Dockerize + deploy ADK Agent to Cloud Run${NC}"
echo -e "${BOLD}======================================================================${NC}"

cd ~/zoo_guide_agent 2>/dev/null || { echo -e "${RED}~/zoo_guide_agent not found${NC}"; exit 1; }

# ------------------------------------------------------------- 1) patch agent.py
echo -e "\n${YELLOW}[1/5] Finishing agent.py TODOs...${NC}"
python3 - "$PWD/agent.py" <<'PYEOF'
import sys, os, re
p = os.path.expanduser(sys.argv[1])
s = open(p, encoding="utf-8").read()

# Un-comment TODO/disabled lines
s = re.sub(r"#\s*(from\s+google\.adk\..*)", r"\1", s)
s = re.sub(r"#\s*(import\s+\w+)", r"\1", s)
s = re.sub(r"#\s*(MCPServer|MCPToolset|google_search|tools\s*=)", r"\1", s)

# Make sure google_search is wired in
if "google_search" not in s:
    s = "from google.adk.tools import google_search\n" + s

# Ensure Agent now has an MCP server + google_search in tools
if "tools=" not in s:
    s = re.sub(r"(root_agent\s*=\s*Agent\(\s*model=\s*.*?)(\))", lambda m: m.group(1) + ",\n    tools=[google_search]" + m.group(2), s, flags=re.S)

# Reference the remote MCP server via MCPServer + mcp_server_urls if missing
if "MCPServer" not in s and "@MCPServer" not in s:
    s += '''

from google.adk.agents.mcp_agent import MCPServer
from google.adk.sessions import InMemorySessionService

zoo_mcp = MCPServer(
    name="zoo-remote",
    transport="streamablehttp",
    server_url="${MCP_URL}",
)
'''
open(p, "w", encoding="utf-8").write(s)
print("  agent.py patched")
PYEOF
# substitute the MCP url inside the heredoc (env not expanded in single-quoted heredoc)
sed -i "s|\${MCP_URL}|$MCP_URL|g" agent.py
grep -nE 'google_search|MCPServer|tools=|server_url|async def' agent.py | head -20

# ------------------------------------------------------------- 2) venv + install
echo -e "\n${YELLOW}[2/5] Creating venv + installing package...${NC}"
gcloud config set project "$PROJECT_ID" --quiet >/dev/null 2>&1
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip -q 2>/dev/null || true
pip install --no-cache-dir -r requirements.txt
# ensure adk CLI available in venv
pip install -q "google-adk>=0.1.0" 2>/dev/null || true
export PATH="$PATH:$HOME/.local/bin"
export GOOGLE_CLOUD_PROJECT="$PROJECT_ID"
export PROJECT_NUMBER="$PROJECT_NUMBER"
export GOOGLE_CLOUD_LOCATION="$REGION"
export GOOGLE_GENAI_USE_ENTERPRISE=1
export MODEL="gemini-3.5-flash"
export SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
export MCP_SERVER_URL="$MCP_URL"
echo -e "${GREEN}  [OK] venv ready.${NC}"

# --------------------------------------------------- 3) deploy ADK agent locally
echo -e "\n${YELLOW}[3/5] Launching 'adk web' locally (Deploy the ADK Agent locally)...${NC}"
echo -e "${CYAN}  Run in a SEPARATE terminal (keep it open):${NC}"
echo -e "${CYAN}    cd ~/zoo_guide_agent && source .venv/bin/activate && adk web${NC}"
echo -e "${CYAN}  Then open http://127.0.0.1:8000 , select zoo_guide_agent, ask:${NC}"
echo -e "${CYAN}    'Where can I find bears?'${NC}"
echo -e "${GREEN}  -> then click 'Check my progress' for this checkpoint, then Ctrl+C twice.${NC}"

echo -e "\n${YELLOW}[4/5] Deploying $ADK_SERVICE to Cloud Run (takes ~10-15 min)...${NC}"
read -p "  Press ENTER after you finished the local 'adk web' test above..." _
source .venv/bin/activate
export PATH="$PATH:$HOME/.local/bin"
adk deploy cloud_run \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --service_name="$ADK_SERVICE" \
  --with_ui \
  . \
  -- \
  --labels=lab-dev=cloud-zoo-run-adk-service \
  || adk deploy cloud_run \
     --project="$PROJECT_ID" \
     --region="$REGION" \
     --service_name="$ADK_SERVICE" \
     --with_ui \
     .

echo -e "\n${YELLOW}[5/5] Verifying service URL...${NC}"
URL=$(gcloud run services describe "$ADK_SERVICE" --region="$REGION" \
  --project="$PROJECT_ID" --format="value(status.url)" 2>/dev/null)
echo -e "${CYAN}  Service URL: ${URL:-https://$ADK_SERVICE-$PROJECT_NUMBER.$REGION.run.app/}${NC}"
echo -e "${CYAN}  Open it, toggle Token Streaming to ON, ask 'Where can I find elephants?'${NC}"
echo -e "${GREEN}  Then click 'Check my progress'.${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  DONE - Task 5 steps executed. Check the two remaining checkpoints.${NC}"
echo -e "${GREEN}======================================================================${NC}"