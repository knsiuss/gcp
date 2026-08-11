#!/bin/bash
# ============================================================================
# GSP1144 - Knowledge Catalog: Qwik Start - Command Line (Tasks 1, 2, 3 Setup)
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
gcloud config set compute/region $REGION --quiet

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP1144 - Knowledge Catalog CLI Setup (Tasks 1 - 3)${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Active Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Region:         ${REGION}${NC}"

# Enable Dataplex API
echo -e "\n${YELLOW}[Step 1] Enabling Dataplex API...${NC}"
gcloud services enable dataplex.googleapis.com --quiet

# Task 1: Create Lake 'ecommerce'
echo -e "\n${YELLOW}[Task 1] Creating Lake 'ecommerce'...${NC}"
gcloud dataplex lakes create ecommerce \
    --location=$REGION \
    --display-name="Ecommerce" \
    --description="Ecommerce Domain" \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

echo "Waiting for Lake 'ecommerce' creation to finish..."
for i in {1..20}; do
  STATE=$(gcloud dataplex lakes describe ecommerce --location=$REGION --format="value(state)" 2>/dev/null || echo "PENDING")
  echo "Lake state: $STATE (Attempt $i/20)"
  if [ "$STATE" == "ACTIVE" ]; then
    break
  fi
  sleep 10
done

# Task 2: Add Zone 'orders-curated-zone'
echo -e "\n${YELLOW}[Task 2] Creating Curated Zone 'orders-curated-zone'...${NC}"
gcloud dataplex zones create orders-curated-zone \
    --location=$REGION \
    --lake=ecommerce \
    --display-name="Orders Curated Zone" \
    --resource-location-type=SINGLE_REGION \
    --type=CURATED \
    --discovery-enabled \
    --discovery-schedule="0 * * * *" \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

echo "Waiting for Zone 'orders-curated-zone' creation to finish..."
for i in {1..20}; do
  STATE=$(gcloud dataplex zones describe orders-curated-zone --location=$REGION --lake=ecommerce --format="value(state)" 2>/dev/null || echo "PENDING")
  echo "Zone state: $STATE (Attempt $i/20)"
  if [ "$STATE" == "ACTIVE" ]; then
    break
  fi
  sleep 10
done

# Task 3: Create BigQuery dataset & Attach Asset 'orders-curated-dataset'
echo -e "\n${YELLOW}[Task 3] Creating BigQuery dataset 'orders' & Attaching Asset 'orders-curated-dataset'...${NC}"
bq mk --location=$REGION --dataset orders 2>/dev/null || true

gcloud dataplex assets create orders-curated-dataset \
    --location=$REGION \
    --lake=ecommerce \
    --zone=orders-curated-zone \
    --display-name="Orders Curated Dataset" \
    --resource-type=BIGQUERY_DATASET \
    --resource-name=projects/$PROJECT_ID/datasets/orders \
    --discovery-enabled \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

echo "Waiting for Asset 'orders-curated-dataset' creation to finish..."
for i in {1..15}; do
  STATE=$(gcloud dataplex assets describe orders-curated-dataset --location=$REGION --lake=ecommerce --zone=orders-curated-zone --format="value(state)" 2>/dev/null || echo "PENDING")
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
echo -e "${YELLOW}2. AFTER Task 1, 2, and 3 are green, run './cleanup_gsp1144.sh' to complete Task 4!${NC}"
