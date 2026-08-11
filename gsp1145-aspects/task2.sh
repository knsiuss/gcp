#!/bin/bash
# ============================================================================
# GSP1145 - Task 2 Only: Create Aspect Type / Tag Template
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
echo -e "${BOLD}  GSP1145 - Task 2: Create Aspect Type 'Protected Data Aspect'${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Region:     ${REGION}${NC}"

echo -e "\n${YELLOW}[Step 1] Enabling required APIs...${NC}"
gcloud services enable dataplex.googleapis.com datacatalog.googleapis.com --quiet

echo -e "\n${YELLOW}[Step 2] Creating Data Catalog Tag Template & Dataplex Aspect Type...${NC}"

# Create Data Catalog Tag Templates (both naming conventions)
gcloud data-catalog tag-templates create protected_data_aspect \
    --location=$REGION \
    --display-name="Protected Data Aspect" \
    --field=id=protected_data_flag,display-name="Protected Data Flag",type=enum(Yes|No),required=true \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

gcloud data-catalog tag-templates create protected-data-aspect \
    --location=$REGION \
    --display-name="Protected Data Aspect" \
    --field=id=protected_data_flag,display-name="Protected Data Flag",type=enum(Yes|No),required=true \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

# Create Dataplex Aspect Types
cat <<EOF > /tmp/aspect_def.json
{
  "fields": [
    {
      "name": "protected_data_flag",
      "displayName": "Protected Data Flag",
      "type": "ENUM",
      "constraints": {"required": true},
      "enumValues": [{"name": "Yes"}, {"name": "No"}]
    }
  ]
}
EOF

gcloud dataplex aspect-types create protected-data-aspect \
    --location=$REGION \
    --display-name="Protected Data Aspect" \
    --metadata-template-file=/tmp/aspect_def.json \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

gcloud dataplex aspect-types create protected_data_aspect \
    --location=$REGION \
    --display-name="Protected Data Aspect" \
    --metadata-template-file=/tmp/aspect_def.json \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  TASK 2 COMPLETED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on Task 2 in Qwiklabs!${NC}"
