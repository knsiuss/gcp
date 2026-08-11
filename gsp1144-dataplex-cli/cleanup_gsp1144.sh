#!/bin/bash
# ============================================================================
# GSP1144 - Task 4: Detach Asset, Delete Zone, and Delete Lake
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

REGION="us-west1"

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP1144 - Task 4 Cleanup (Asset, Zone, Lake Deletion)${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Region:     ${REGION}${NC}"

# Detach / Delete Asset 'orders-curated-dataset'
echo -e "\n${YELLOW}[Step 1] Detaching asset 'orders-curated-dataset'...${NC}"
gcloud dataplex assets delete orders-curated-dataset \
    --location=$REGION \
    --lake=ecommerce \
    --zone=orders-curated-zone \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

echo "Waiting for asset deletion..."
sleep 15

# Delete Zone 'orders-curated-zone'
echo -e "\n${YELLOW}[Step 2] Deleting zone 'orders-curated-zone'...${NC}"
gcloud dataplex zones delete orders-curated-zone \
    --location=$REGION \
    --lake=ecommerce \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

echo "Waiting for zone deletion..."
sleep 15

# Delete Lake 'ecommerce'
echo -e "\n${YELLOW}[Step 3] Deleting lake 'ecommerce'...${NC}"
gcloud dataplex lakes delete ecommerce \
    --location=$REGION \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  TASK 4 CLEANUP COMPLETED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on Task 4 in Qwiklabs!${NC}"
