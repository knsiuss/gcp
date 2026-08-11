#!/bin/bash
# ============================================================================
# GSP1145 - Task 3 Only: Add Aspect / Tags to Entry and Columns
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

# Detect dataset 'customers' region
REGION=$(bq show --format=json $PROJECT_ID:customers 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin).get('location', 'us-west1').lower())" 2>/dev/null || echo "us-west1")

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP1145 - Task 3: Add Aspect to Table & Columns${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Region:     ${REGION}${NC}"

target_resource="projects/${PROJECT_ID}/datasets/customers/tables/customer_details"
entry_id=$(echo -n "$target_resource" | base64 | tr -d '\n' | tr -d '=')
entry_path="projects/${PROJECT_ID}/locations/${REGION}/entryGroups/@bigquery/entries/${entry_id}"

echo -e "\n${YELLOW}[Step 1] Attaching Aspect/Tag to table customer_details...${NC}"
for template_name in "protected_data_aspect" "protected-data-aspect"; do
    gcloud data-catalog tags create \
        --entry="${entry_path}" \
        --tag-template="projects/${PROJECT_ID}/locations/${REGION}/tagTemplates/${template_name}" \
        --fields=protected_data_flag=Yes \
        --project="${PROJECT_ID}" \
        --quiet 2>/dev/null || true
done

echo -e "\n${YELLOW}[Step 2] Attaching Aspect/Tag to columns...${NC}"
columns=("first_name" "last_name" "email" "state" "zip" "country" "city" "latitude" "longitude")

for col in "${columns[@]}"; do
    for template_name in "protected_data_aspect" "protected-data-aspect"; do
        gcloud data-catalog tags create \
            --entry="${entry_path}" \
            --tag-template="projects/${PROJECT_ID}/locations/${REGION}/tagTemplates/${template_name}" \
            --column="${col}" \
            --fields=protected_data_flag=Yes \
            --project="${PROJECT_ID}" \
            --quiet 2>/dev/null || true
    done
done

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  TASK 3 COMPLETED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on Task 3 in Qwiklabs!${NC}"
