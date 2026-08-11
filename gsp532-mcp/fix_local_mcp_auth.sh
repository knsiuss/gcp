#!/bin/bash
# ============================================================================
# GSP532 - Fix Local MCP Authorization Header in agent.py
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
echo -e "${BOLD}  GSP532 - Patching agent.py with Bearer Authorization Header${NC}"
echo -e "${BOLD}======================================================================${NC}"

ZOO_DIR=~/zoo_guide_agent

cp patch_agent.py "$ZOO_DIR/" 2>/dev/null || true
cd "$ZOO_DIR"
python3 patch_agent.py 2>/dev/null || python3 ~/gcp-labs/gsp532-mcp/patch_agent.py

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  AGENT.PY AUTH PATCH COMPLETED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"