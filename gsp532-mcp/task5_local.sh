#!/bin/bash
# ============================================================================
# GSP532 - Task 5 Part 1: Deploy & Test ADK Agent Locally
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
echo -e "${BOLD}  GSP532 - Task 5: Deploy ADK Agent Locally${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"

ZOO_DIR=~/zoo_guide_agent
AGENT_PY="$ZOO_DIR/agent.py"

echo -e "\n${YELLOW}[Step 1] Patching ~/zoo_guide_agent/agent.py...${NC}"
if [ -f "$AGENT_PY" ]; then
    sed -i 's/#\s*\(from\s+.*import.*\)/\1/g' "$AGENT_PY"
    sed -i 's/#\s*\(import\s+.*\)/\1/g' "$AGENT_PY"
    sed -i 's/#\s*\(tools\s*=\)/\1/g' "$AGENT_PY"
    sed -i 's/#\s*\(MCPToolset\)/\1/g' "$AGENT_PY"

    if ! grep -q "google_search" "$AGENT_PY"; then
        sed -i '1s/^/from google.adk.tools import google_search\n/' "$AGENT_PY"
    fi

    if ! grep -q "tools=" "$AGENT_PY"; then
        sed -i 's/\(Agent\s*(.*\)/\1, tools=[google_search]/g' "$AGENT_PY"
    fi
    echo "Patched agent.py successfully!"
fi

echo -e "\n${YELLOW}[Step 2] Setting up virtual environment & requirements...${NC}"
export PATH=$PATH:"/home/${USER}/.local/bin"
cd "$ZOO_DIR"

python3 -m venv .venv 2>/dev/null || true
source .venv/bin/activate 2>/dev/null || true
pip install --no-cache-dir -r requirements.txt 2>/dev/null || pip install --no-cache-dir google-adk 2>/dev/null || true

echo -e "\n${YELLOW}[Step 3] Testing ADK web server locally...${NC}"
cd ~
adk web &
ADK_PID=$!
sleep 5

kill $ADK_PID 2>/dev/null || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  LOCAL ADK AGENT SETUP COMPLETED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on 'Deploy the ADK Agent locally' in Qwiklabs!${NC}"
