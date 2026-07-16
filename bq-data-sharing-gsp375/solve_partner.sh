#!/bin/bash
# solve_partner.sh
# Automating Partner tasks for GSP375 (Share Data using Google Data Cloud: Challenge Lab)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}    GSP375: Data Sharing Partner Solver (Task 1)                     ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Set the correct Partner project
PARTNER_PROJECT="qwiklabs-gcp-04-321389a30a6e"
echo -e "${YELLOW}[*] Setting active project to Partner Project: $PARTNER_PROJECT...${NC}"
gcloud config set project "$PARTNER_PROJECT"

# Detect active project
export PROJECT_ID=$(gcloud config get-value project)
echo -e "${YELLOW}[*] Partner Project ID:${NC} $PROJECT_ID"

# Prompt for names (prefilled with current lab values)
read -p "Enter Partner View Name (default: authorized_view_vv1z): " VIEW_NAME
VIEW_NAME=${VIEW_NAME:-authorized_view_vv1z}

read -p "Enter Customer Username (default: student-03-db01902f575a@qwiklabs.net): " CUSTOMER_USER
CUSTOMER_USER=${CUSTOMER_USER:-student-03-db01902f575a@qwiklabs.net}

# Ensure demo_dataset exists
bq mk --dataset=true demo_dataset || true

# Create the authorized view
echo -e "\n${YELLOW}[*] Creating authorized view $VIEW_NAME in demo_dataset...${NC}"
bq mk --use_legacy_sql=false --view \
"SELECT * FROM \`bigquery-public-data.geo_us_boundaries.zip_codes\`" \
demo_dataset."$VIEW_NAME"

# Authorize the view in the dataset demo_dataset
echo -e "\n${YELLOW}[*] Authorizing the view in demo_dataset ACL...${NC}"
bq show --format=prettyjson demo_dataset > dataset.json
python3 update_acl.py view dataset.json "$PROJECT_ID" demo_dataset "$VIEW_NAME"
bq update --source dataset.json demo_dataset

# Assign BigQuery Data Viewer role to Customer User on the dataset
echo -e "\n${YELLOW}[*] Granting BigQuery Data Viewer access to $CUSTOMER_USER...${NC}"
bq show --format=prettyjson demo_dataset > dataset.json
python3 update_acl.py user dataset.json "$CUSTOMER_USER" "READER"
bq update --source dataset.json demo_dataset

rm -f dataset.json

echo -e "\n${GREEN}[+] Partner tasks completed! You can now Check Progress for Task 1 in Qwiklabs.${NC}"
echo -e "${GREEN}======================================================================${NC}"
