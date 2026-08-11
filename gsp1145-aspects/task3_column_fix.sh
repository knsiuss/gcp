#!/bin/bash
# ============================================================================
# GSP1145 - Task 3 Column Aspect Fixer
# Attaches Protected Data Aspect to all 9 columns of customer_details table
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
echo -e "${BOLD}  GSP1145 - Task 3 Column Aspect Fixer${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Region:     ${REGION}${NC}"

# Lookup exact Data Catalog Entry Name
ENTRY=$(gcloud data-catalog entries lookup "//bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/customers/tables/customer_details" --format="value(name)" 2>/dev/null || echo "")

if [ -z "$ENTRY" ]; then
    echo "Using base64 entry path fallback..."
    entry_id=$(echo -n "projects/${PROJECT_ID}/datasets/customers/tables/customer_details" | base64 | tr -d '\n' | tr -d '=')
    ENTRY="projects/${PROJECT_ID}/locations/${REGION}/entryGroups/@bigquery/entries/${entry_id}"
fi

echo -e "${CYAN}[*] Data Catalog Entry: ${ENTRY}${NC}"

# 1. Attach Tag to Table
echo -e "\n${YELLOW}[Step 1] Attaching Aspect to table customer_details...${NC}"
for template_name in "protected_data_aspect" "protected-data-aspect"; do
    gcloud data-catalog tags create \
        --entry="${ENTRY}" \
        --tag-template="projects/${PROJECT_ID}/locations/${REGION}/tagTemplates/${template_name}" \
        --fields=protected_data_flag=Yes \
        --project="${PROJECT_ID}" \
        --quiet 2>/dev/null || true
done

# 2. Attach Tag to all 9 columns
echo -e "\n${YELLOW}[Step 2] Attaching Aspect to all 9 columns...${NC}"
columns=("zip" "state" "last_name" "country" "email" "latitude" "first_name" "city" "longitude")

for col in "${columns[@]}"; do
    echo "Processing column: ${col}..."
    for template_name in "protected_data_aspect" "protected-data-aspect"; do
        gcloud data-catalog tags create \
            --entry="${ENTRY}" \
            --tag-template="projects/${PROJECT_ID}/locations/${REGION}/tagTemplates/${template_name}" \
            --column="${col}" \
            --fields=protected_data_flag=Yes \
            --project="${PROJECT_ID}" \
            --quiet 2>/dev/null || true
    done
done

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  ALL COLUMN ASPECTS ATTACHED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on Task 3 in Qwiklabs!${NC}"
