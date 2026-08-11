#!/bin/bash
# ============================================================================
# GSP1143 - Knowledge Catalog: Qwik Start - Console (Create Lake, Zone, Asset)
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

ACTIVE_ACCOUNT=$(gcloud auth list --format="value(account)" 2>/dev/null | head -1)
if [ -n "$ACTIVE_ACCOUNT" ]; then
    gcloud config set account "$ACTIVE_ACCOUNT" --quiet 2>/dev/null || true
fi

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID="$DEVSHELL_PROJECT_ID"
    gcloud config set project "$PROJECT_ID" --quiet
fi

REGION="us-west1"

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP1143 - Knowledge Catalog / Dataplex Setup (Task 1 - 3)${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Active Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Region:         ${REGION}${NC}"

# Enable Dataplex API
echo -e "\n${YELLOW}[Step 1] Enabling Dataplex API...${NC}"
gcloud services enable dataplex.googleapis.com --quiet

# Task 1: Create Lake 'sensors'
echo -e "\n${YELLOW}[Task 1] Creating Lake 'sensors'...${NC}"
gcloud dataplex lakes create sensors \
    --location=$REGION \
    --display-name="sensors" \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

echo "Waiting for Lake 'sensors' creation to finish..."
for i in {1..20}; do
  STATE=$(gcloud dataplex lakes describe sensors --location=$REGION --format="value(state)" 2>/dev/null || echo "PENDING")
  echo "Lake state: $STATE (Attempt $i/20)"
  if [ "$STATE" == "ACTIVE" ]; then
    break
  fi
  sleep 10
done

# Task 2: Add Zone 'temperature-raw-data'
echo -e "\n${YELLOW}[Task 2] Adding Zone 'temperature raw data' to Lake 'sensors'...${NC}"
gcloud dataplex zones create temperature-raw-data \
    --location=$REGION \
    --lake=sensors \
    --display-name="temperature raw data" \
    --type=RAW \
    --resource-location-type=SINGLE_REGION \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

echo "Waiting for Zone 'temperature-raw-data' creation to finish..."
for i in {1..20}; do
  STATE=$(gcloud dataplex zones describe temperature-raw-data --location=$REGION --lake=sensors --format="value(state)" 2>/dev/null || echo "PENDING")
  echo "Zone state: $STATE (Attempt $i/20)"
  if [ "$STATE" == "ACTIVE" ]; then
    break
  fi
  sleep 10
done

# Task 3: Create Storage Bucket and Attach Asset 'measurements'
echo -e "\n${YELLOW}[Task 3] Creating Cloud Storage Bucket & Attaching Asset 'measurements'...${NC}"
gcloud storage buckets create gs://$PROJECT_ID --location=$REGION --project=$PROJECT_ID 2>/dev/null || true

gcloud dataplex assets create measurements \
    --location=$REGION \
    --lake=sensors \
    --zone=temperature-raw-data \
    --display-name="measurements" \
    --resource-type=STORAGE_BUCKET \
    --resource-name="projects/$PROJECT_ID/buckets/$PROJECT_ID" \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

echo "Waiting for Asset 'measurements' creation to finish..."
for i in {1..15}; do
  STATE=$(gcloud dataplex assets describe measurements --location=$REGION --lake=sensors --zone=temperature-raw-data --format="value(state)" 2>/dev/null || echo "PENDING")
  echo "Asset state: $STATE (Attempt $i/15)"
  if [ "$STATE" == "ACTIVE" ]; then
    break
  fi
  sleep 10
done

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  TASKS 1, 2, AND 3 SETUP COMPLETED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}IMPORTANT STEPS:${NC}"
echo -e "${YELLOW}1. Click 'Check my progress' on Task 1, Task 2, and Task 3 in Qwiklabs NOW.${NC}"
echo -e "${YELLOW}2. AFTER Task 1, 2, and 3 are green, run './cleanup_gsp1143.sh' to complete Task 4!${NC}"
