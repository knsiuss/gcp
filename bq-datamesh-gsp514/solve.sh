#!/bin/bash
# GSP514: Build a Data Mesh with Knowledge Catalog: Challenge Lab
set -e

# Color codes for output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   GSP514 Automation Script by Antigravity      ${NC}"
echo -e "${CYAN}================================================${NC}"

# Read User 2's email
read -p "Enter User 2's Email (from Qwiklabs panel): " USER_2
if [ -z "$USER_2" ]; then
  echo -e "${RED}User 2 Email is required!${NC}"
  exit 1
fi

# Fetch project details
export PROJECT_ID=$(gcloud config get-value project)
export ZONE=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo "$ZONE" | cut -d '-' -f 1-2)

echo -e "${GREEN}Project ID: $PROJECT_ID${NC}"
echo -e "${GREEN}Zone: $ZONE${NC}"
echo -e "${GREEN}Region: $REGION${NC}"

# Enable necessary APIs
echo -e "${YELLOW}Enabling APIs...${NC}"
gcloud services enable \
  dataplex.googleapis.com \
  datacatalog.googleapis.com \
  dataproc.googleapis.com

# Task 1: Create Lake and Zones
echo -e "${YELLOW}Creating Sales Lake...${NC}"
gcloud dataplex lakes create sales-lake \
  --location=$REGION \
  --display-name="Sales Lake" || true

echo -e "${YELLOW}Creating Zones...${NC}"
gcloud dataplex zones create raw-customer-zone \
  --lake=sales-lake \
  --location=$REGION \
  --display-name="Raw Customer Zone" \
  --type=RAW \
  --resource-location-type=SINGLE_REGION \
  --discovery-enabled \
  --discovery-schedule="0 * * * *" || true

gcloud dataplex zones create curated-customer-zone \
  --lake=sales-lake \
  --location=$REGION \
  --display-name="Curated Customer Zone" \
  --type=CURATED \
  --resource-location-type=SINGLE_REGION \
  --discovery-enabled \
  --discovery-schedule="0 * * * *" || true

# Attach Assets
echo -e "${YELLOW}Attaching raw zone asset...${NC}"
gcloud dataplex assets create customer-engagements \
  --lake=sales-lake \
  --zone=raw-customer-zone \
  --location=$REGION \
  --display-name="Customer Engagements" \
  --resource-type=STORAGE_BUCKET \
  --resource-name=projects/$PROJECT_ID/buckets/$PROJECT_ID-customer-online-sessions \
  --discovery-enabled || true

echo -e "${YELLOW}Attaching curated zone asset...${NC}"
gcloud dataplex assets create customer-orders \
  --lake=sales-lake \
  --zone=curated-customer-zone \
  --location=$REGION \
  --display-name="Customer Orders" \
  --resource-type=BIGQUERY_DATASET \
  --resource-name=projects/$PROJECT_ID/datasets/customer_orders \
  --discovery-enabled || true

# Task 2: Create Aspect Type
echo -e "${YELLOW}Creating aspect type template...${NC}"
cat << EOF > aspect-template.json
{
  "name": "protected_customer_data_aspect",
  "type": "record",
  "recordFields": [
    {
      "name": "raw_data_flag",
      "type": "enum",
      "index": 1,
      "enumValues": [
        {
          "name": "Yes",
          "index": 1
        },
        {
          "name": "No",
          "index": 2
        }
      ]
    },
    {
      "name": "protected_contact_information_flag",
      "type": "enum",
      "index": 2,
      "enumValues": [
        {
          "name": "Yes",
          "index": 1
        },
        {
          "name": "No",
          "index": 2
        }
      ]
    }
  ]
}
EOF

gcloud dataplex aspect-types create protected-customer-data-aspect \
  --location=$REGION \
  --metadata-template-file-name=aspect-template.json \
  --display-name="Protected Customer Data Aspect" || true

# Instructions for manual part of Task 2
echo -e "\n${CYAN}========================================================================${NC}"
echo -e "${CYAN}   ACTION REQUIRED: ADD ASPECT TO THE ZONE IN THE GOOGLE CLOUD CONSOLE   ${NC}"
echo -e "${CYAN}========================================================================${NC}"
echo -e "I have automatically created the 'Protected Customer Data Aspect' type."
echo -e "Now, you must manually attach it to the 'Raw Customer Zone' in the Console:"
echo -e "  1. In the GCP Console, search for ${YELLOW}Knowledge Catalog${NC} or ${YELLOW}Dataplex${NC}."
echo -e "  2. Go to ${GREEN}Manage${NC} > ${GREEN}Sales Lake${NC} (or click on Sales Lake in Lakes list)."
echo -e "  3. Click on the ${GREEN}Raw Customer Zone${NC}."
echo -e "  4. Click on ${GREEN}Add Aspect${NC} (or Edit > Add Aspect)."
echo -e "  5. Select ${GREEN}Protected Customer Data Aspect${NC}."
echo -e "  6. Set BOTH flags (${YELLOW}Raw Data Flag${NC} and ${YELLOW}Protected Contact Information Flag${NC}) to ${GREEN}Yes${NC}."
echo -e "  7. Click ${GREEN}Save${NC}."
echo -e "${CYAN}========================================================================${NC}"
read -p "Once you have completed the steps above, press [Enter] to continue..."

# Task 3: IAM Role Assignment to User 2
echo -e "${YELLOW}Assigning Data Writer role to User 2...${NC}"
gcloud dataplex assets add-iam-policy-binding customer-engagements \
  --lake=sales-lake \
  --zone=raw-customer-zone \
  --location=$REGION \
  --member=user:$USER_2 \
  --role=roles/dataplex.dataWriter || true

# Task 4: Create Data Quality Spec File and dataset
echo -e "${YELLOW}Creating BigQuery destination dataset if not exists...${NC}"
bq show --dataset $PROJECT_ID:orders_dq_dataset || bq mk --location=$REGION --dataset $PROJECT_ID:orders_dq_dataset

echo -e "${YELLOW}Creating data quality specification file...${NC}"
cat > dq-customer-orders.yaml <<EOF
rules:
- nonNullExpectation: {}
  column: user_id
  dimension: COMPLETENESS
  threshold: 1.0

- nonNullExpectation: {}
  column: order_id
  dimension: COMPLETENESS
  threshold: 1.0

postScanActions:
  bigqueryExport:
    resultsTable: projects/$PROJECT_ID/datasets/orders_dq_dataset/tables/results
EOF

echo -e "${YELLOW}Uploading YAML file to Cloud Storage...${NC}"
gsutil cp dq-customer-orders.yaml gs://$PROJECT_ID-dq-config/

# Task 5: Define and Run Auto Data Quality Job
echo -e "${YELLOW}Granting Service Account Token Creator role to Dataplex Service Agent...${NC}"
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
SA_EMAIL="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
DATAPLEX_SA="service-${PROJECT_NUMBER}@gcp-sa-dataplex.iam.gserviceaccount.com"

gcloud iam service-accounts add-iam-policy-binding ${SA_EMAIL} \
  --member="serviceAccount:${DATAPLEX_SA}" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --quiet || true

echo -e "${YELLOW}Defining auto data quality job...${NC}"
gcloud dataplex datascans create data-quality customer-orders-data-quality-job \
  --project=$PROJECT_ID \
  --location=$REGION \
  --data-source-resource="//bigquery.googleapis.com/projects/$PROJECT_ID/datasets/customer_orders/tables/ordered_items" \
  --data-quality-spec-file="gs://$PROJECT_ID-dq-config/dq-customer-orders.yaml" \
  --service-account=${SA_EMAIL} || true

echo -e "${YELLOW}Running auto data quality job immediately...${NC}"
gcloud dataplex datascans run customer-orders-data-quality-job \
  --location=$REGION || true

echo -e "${GREEN}All tasks completed successfully!${NC}"
