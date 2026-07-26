#!/bin/bash
# ============================================================================
# GSP532 - Build a Smart Cloud Application with Vibe Coding and MCP
# Automated Shell Solution Script
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Auto-activate gcloud account & project
ACTIVE_ACCOUNT=$(gcloud auth list --format="value(account)" 2>/dev/null | head -1)
if [ -n "$ACTIVE_ACCOUNT" ]; then
    gcloud config set account "$ACTIVE_ACCOUNT" --quiet 2>/dev/null || true
fi

if [ -n "$DEVSHELL_PROJECT_ID" ]; then
    gcloud config set project "$DEVSHELL_PROJECT_ID" --quiet 2>/dev/null || true
fi

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP532 - Vibe Coding and MCP Challenge Lab Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Active Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"

# Ensure google-adk & dependencies installed
export PATH=$PATH:"/home/${USER}/.local/bin"
python3 -m pip install -q google-adk pydantic uv 2>/dev/null || true

# Run python solver script
cp ~/gcp-labs/gsp532-mcp/solve_gsp532.py . 2>/dev/null || true
python3 solve_gsp532.py || python3 ~/gcp-labs/gsp532-mcp/solve_gsp532.py
