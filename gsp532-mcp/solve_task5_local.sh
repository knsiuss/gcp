#!/bin/bash
# ============================================================================
# GSP532 - Task 5 Local ADK Agent Complete Solver
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
echo -e "${BOLD}  GSP532 - Task 5 Local: Setup & Deploy ADK Agent Locally${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"

ZOO_DIR=~/zoo_guide_agent

echo -e "\n${YELLOW}[Step 1] Creating clean agent.py with patch_agent.py...${NC}"
cp patch_agent.py "$ZOO_DIR/" 2>/dev/null || true
cd "$ZOO_DIR"
python3 patch_agent.py 2>/dev/null || python3 ~/gcp-labs/gsp532-mcp/patch_agent.py

echo -e "\n${YELLOW}[Step 2] Setting up virtual environment & installing dependencies...${NC}"
cd "$ZOO_DIR"
python3 -m venv .venv
source .venv/bin/activate
pip install --no-cache-dir -r requirements.txt
pip install -e . 2>/dev/null || true

echo -e "\n${YELLOW}[Step 3] Running ADK web server locally...${NC}"
cd ~
export PATH=$PATH:"/home/${USER}/.local/bin"
source "$ZOO_DIR/.venv/bin/activate" 2>/dev/null || true

adk web &
ADK_PID=$!
sleep 6

kill $ADK_PID 2>/dev/null || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  TASK 5 LOCAL ADK AGENT SOLVED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on 'Deploy the ADK Agent locally' in Qwiklabs!${NC}"
