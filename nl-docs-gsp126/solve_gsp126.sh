#!/bin/bash
# ============================================================================
# GSP126 - Using the Natural Language API from Google Docs
# Automates the scriptable part of the lab:
#   Task 1  Enable the Cloud Natural Language API
#   Task 2  Create an API key restricted to the Natural Language API
# Tasks 3 & 4 must be done manually in Google Docs (Apps Script) - the ready
#          to paste script is included in this folder: code.gs
# Usage (in the lab's Cloud Shell):
#   git clone https://github.com/knsiuss/gcp.git gcp-labs
#   cd gcp-labs/nl-docs-gsp126
#   chmod +x solve_gsp126.sh
#   ./solve_gsp126.sh
# ============================================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

ACTIVE_ACCOUNT=$(gcloud auth list --format="value(account)" 2>/dev/null | head -1)
[ -n "$ACTIVE_ACCOUNT" ] && gcloud config set account "$ACTIVE_ACCOUNT" --quiet 2>/dev/null || true
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP126 - Natural Language API from Google Docs Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project: ${PROJECT_ID}${NC}"

KEY_NAME="nl-lab-api-key"
DISPLAY_NAME="Natural Language API key"

# ============================================================================
# Task 1: Enable the Cloud Natural Language API
# ============================================================================
echo -e "\n${YELLOW}[Task 1] Enabling Cloud Natural Language API...${NC}"
gcloud services enable language.googleapis.com --quiet
echo -e "${GREEN}  [OK] language.googleapis.com enabled${NC}"
echo -e "\n${GREEN}  ==> Task 1 DONE - click 'Check my progress'.${NC}"

# ============================================================================
# Task 2: Create an API key restricted to the Natural Language API
# ============================================================================
echo -e "\n${YELLOW}[Task 2] Creating API key restricted to Natural Language API...${NC}"

# Detect api-keys release track (GA preferred, then alpha)
if gcloud services api-keys --help >/dev/null 2>&1; then
  KEYS="gcloud services api-keys"
else
  KEYS="gcloud alpha services api-keys"
fi
echo -e "${CYAN}[*] api-keys command: ${KEYS}${NC}"

# Delete any existing key with the same name so create does not collide
gcloud services api-keys list --filter="displayName=$DISPLAY_NAME" \
  --format="value(name)" 2>/dev/null | while read -r kname; do
  [ -n "$kname" ] && { echo "  Removing existing key $kname..."; $KEYS delete "$kname" --quiet >/dev/null 2>&1 || true; }
done

$KEYS create --display-name="$DISPLAY_NAME" \
  --api-target="service=language.googleapis.com" \
  --format="value(response.keyString)" > /tmp/nl_apikey.txt 2>/dev/null \
  || { echo -e "${RED}  [!!] API key creation via gcloud failed - create it manually in the console:${NC}";
       echo "      APIs & Services > Credentials > Create credentials > API key";
       echo "      Restrict it to Cloud Natural Language API."; }

API_KEY=$(cat /tmp/nl_apikey.txt 2>/dev/null || true)
if [ -n "$API_KEY" ]; then
  echo -e "${GREEN}  [OK] API key created: $API_KEY${NC}"
  echo "$API_KEY" > api_key.txt
  echo -e "${CYAN}  [*] Key saved to api_key.txt - paste it into code.gs (retrieveSentiment).${NC}"
  echo -e "\n${GREEN}  ==> Task 2 DONE - click 'Check my progress'.${NC}"
else
  echo -e "${YELLOW}  [*] No API key captured - create it in the console, then click 'Check my progress'.${NC}"
fi

# ============================================================================
# Tasks 3 & 4: manual - Google Docs + Apps Script
# ============================================================================
echo -e "\n${BOLD}======================================================================${NC}"
echo -e "${BOLD}  TASKS 3 & 4 (manual, in Google Docs)${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}1. Open a new Google Doc -> Extensions -> Apps Script${NC}"
echo -e "${CYAN}2. Delete all code and paste the full (Task 3) Apps Script from code.gs${NC}"
echo -e "${CYAN}3. Save project, reload doc, add the Alice in Wonderland text${NC}"
echo -e "${CYAN}4. Select text -> Natural Language Tools -> Mark Sentiment (authorize)${NC}"
echo -e "${CYAN}   -> click 'Check my progress' for Task 3 (yellow highlight = OK)${NC}"
echo -e "${CYAN}5. Fill in the retrieveSentiment function with your API key (Task 4)${NC}"
echo -e "${CYAN}   -> full code with your key at the bottom of code.gs${NC}"
echo -e "${CYAN}6. Reload, select text, Mark Sentiment -> text gets colored by score${NC}"
echo -e "${CYAN}   -> click 'Check my progress' for Task 4${NC}"
echo -e "${BOLD}======================================================================${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP126 SOLVER FINISHED (Tasks 1-2 automated, Tasks 3-4 manual)${NC}"
echo -e "${GREEN}======================================================================${NC}"