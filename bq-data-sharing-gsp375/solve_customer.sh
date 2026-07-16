#!/bin/bash
# solve_customer.sh
# Automating Customer tasks for GSP375 (Share Data using Google Data Cloud: Challenge Lab)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}    GSP375: Customer Solver (Tasks 2 & 3)                            ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Set the correct Customer project
CUSTOMER_PROJECT="qwiklabs-gcp-00-f02f67f8365d"
echo -e "${YELLOW}[*] Setting active project to Customer Project: $CUSTOMER_PROJECT...${NC}"
gcloud config set project "$CUSTOMER_PROJECT"

# Detect active project
export PROJECT_ID=$(gcloud config get-value project)
echo -e "${YELLOW}[*] Customer Project ID:${NC} $PROJECT_ID"

# Prompt for names (prefilled with current lab values)
read -p "Enter Customer View Name (default: customer_authorized_view_sp0g): " CUST_VIEW
CUST_VIEW=${CUST_VIEW:-customer_authorized_view_sp0g}

read -p "Enter Partner Project ID (default: qwiklabs-gcp-04-321389a30a6e): " PARTNER_PROJECT
PARTNER_PROJECT=${PARTNER_PROJECT:-qwiklabs-gcp-04-321389a30a6e}

read -p "Enter Partner View Name (default: authorized_view_vv1z): " PARTNER_VIEW
PARTNER_VIEW=${PARTNER_VIEW:-authorized_view_vv1z}

read -p "Enter Partner Username (default: student-04-cb76c855c4c5@qwiklabs.net): " PARTNER_USER
PARTNER_USER=${PARTNER_USER:-student-04-cb76c855c4c5@qwiklabs.net}

# Task 2: Update the customer data table
echo -e "\n${YELLOW}[Step 1] Task 2: Updating customer data table using Partner authorized view...${NC}"
bq query --use_legacy_sql=false \
"UPDATE \`${PROJECT_ID}.customer_dataset.customer_info\` cust
SET cust.county=vw.county
FROM \`${PARTNER_PROJECT}.demo_dataset.${PARTNER_VIEW}\` vw
WHERE vw.zip_code=cust.postal_code;"

# Task 3: Create the customer authorized view
echo -e "\n${YELLOW}[Step 2] Task 3: Creating customer authorized view $CUST_VIEW...${NC}"
bq mk --use_legacy_sql=false --view \
"SELECT county, COUNT(1) AS Count
FROM \`${PROJECT_ID}.customer_dataset.customer_info\` cust
GROUP BY county
HAVING county is not null" \
customer_dataset."$CUST_VIEW"

# Authorize the customer view in customer_dataset
echo -e "\n${YELLOW}[Step 3] Authorizing the view in customer_dataset ACL...${NC}"
bq show --format=prettyjson customer_dataset > dataset.json
python3 update_acl.py view dataset.json "$PROJECT_ID" customer_dataset "$CUST_VIEW"
bq update --source dataset.json customer_dataset

# Assign BigQuery Data Viewer role to Partner User on the dataset
echo -e "\n${YELLOW}[Step 4] Granting BigQuery Data Viewer access to $PARTNER_USER...${NC}"
bq show --format=prettyjson customer_dataset > dataset.json
python3 update_acl.py user dataset.json "$PARTNER_USER" "READER"
bq update --source dataset.json customer_dataset

rm -f dataset.json

echo -e "\n${GREEN}[+] Customer tasks completed! You can now Check Progress for Tasks 2 & 3 in Qwiklabs.${NC}"
echo -e "${GREEN}======================================================================${NC}"
