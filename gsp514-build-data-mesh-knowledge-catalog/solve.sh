#!/bin/bash
# GSP514: Build a Data Mesh with Knowledge Catalog: Challenge Lab
# ============================================================
# Usage: source solve.sh
# NOTE: Run this script in Cloud Shell, not locally.
#       Some tasks (Task 2 aspect UI, Task 5 DQ job) need console steps.
# ============================================================

YELLOW='\033[0;33m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
echo -e "${YELLOW}Starting GSP514 Challenge Lab solver...${NC}"

# ============================================================
# Setup — Project & Region
# ============================================================
export PROJECT_ID=$(gcloud config get-value project)
export REGION=$(gcloud config get-value compute/region 2>/dev/null)
if [ -z "$REGION" ]; then
  export REGION=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items.google-compute-default-region)" 2>/dev/null)
fi
[ -z "$REGION" ] && export REGION="us-central1"

echo -e "${GREEN}Project: $PROJECT_ID | Region: $REGION${NC}"

# ============================================================
# Enable APIs
# ============================================================
echo -e "\n${YELLOW}Enabling APIs...${NC}"
gcloud services enable dataplex.googleapis.com datacatalog.googleapis.com

# ============================================================
# Task 1: Create Lake → 2 Zones → 2 Assets
# ============================================================
echo -e "\n${YELLOW}[Task 1] Creating lake, zones & assets...${NC}"

# Lake
gcloud dataplex lakes create sales-lake \
  --location="$REGION" \
  --display-name="Sales Lake"

# Zones
gcloud dataplex zones create raw-customer-zone \
  --lake=sales-lake --location="$REGION" \
  --display-name="Raw Customer Zone" \
  --type=RAW --resource-location-type=SINGLE_REGION

gcloud dataplex zones create curated-customer-zone \
  --lake=sales-lake --location="$REGION" \
  --display-name="Curated Customer Zone" \
  --type=CURATED --resource-location-type=SINGLE_REGION

# Assets
export BUCKET_NAME="${PROJECT_ID}-customer-online-sessions"

gcloud dataplex assets create customer-engagements \
  --lake=sales-lake --zone=raw-customer-zone --location="$REGION" \
  --display-name="Customer Engagements" \
  --resource-type=STORAGE_BUCKET \
  --resource-name="projects/$PROJECT_ID/buckets/$BUCKET_NAME"

gcloud dataplex assets create customer-orders \
  --lake=sales-lake --zone=curated-customer-zone --location="$REGION" \
  --display-name="Customer Orders" \
  --resource-type=BIGQUERY_DATASET \
  --resource-name="projects/$PROJECT_ID/datasets/customer_orders"

echo -e "${GREEN}[T1 OK] Lake + zones + assets created${NC}"

# ============================================================
# Task 2: Create Aspect Type & Apply to Zone
# ============================================================
echo -e "\n${YELLOW}[Task 2] Creating aspect type...${NC}"

# Create aspect type with metadata template (JSON Schema)
gcloud dataplex aspect-types create protected-customer-data-aspect \
  --location="$REGION" \
  --display-name="Protected Customer Data Aspect" \
  --metadata-template=@- <<'JSONEOF'
{
  "fields": [
    {
      "name": "raw-data-flag",
      "displayName": "Raw Data Flag",
      "dataType": {
        "enumType": {
          "allowedValues": [
            {"displayName": "Yes", "index": 0},
            {"displayName": "No", "index": 1}
          ]
        }
      }
    },
    {
      "name": "protected-contact-information-flag",
      "displayName": "Protected Contact Information Flag",
      "dataType": {
        "enumType": {
          "allowedValues": [
            {"displayName": "Yes", "index": 0},
            {"displayName": "No", "index": 1}
          ]
        }
      }
    }
  ]
}
JSONEOF

# ── Apply aspect to Raw Customer Zone entry ──
echo -e "${YELLOW}Looking up Raw Customer Zone entry...${NC}"

ZONE_ENTRY=$(gcloud data-catalog entries lookup \
  --linked-resource="//dataplex.googleapis.com/projects/$PROJECT_ID/locations/$REGION/lakes/sales-lake/zones/raw-customer-zone" \
  --format="value(name)" 2>/dev/null)

if [ -n "$ZONE_ENTRY" ]; then
  # Update entry with aspect using REST API
  ASPECT_PAYLOAD=$(cat <<EOF
{
  "aspects": {
    "projects/$PROJECT_ID/locations/$REGION/aspectTypes/protected-customer-data-aspect": {
      "data": {
        "fields": {
          "raw-data-flag": {"enumValue": "Yes"},
          "protected-contact-information-flag": {"enumValue": "Yes"}
        }
      }
    }
  }
}
EOF
)
  curl -s -X PATCH \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "Content-Type: application/json" \
    "https://datacatalog.googleapis.com/v1/$ZONE_ENTRY?updateMask=aspects" \
    -d "$ASPECT_PAYLOAD" > /dev/null
  echo -e "${GREEN}Aspect applied to entry${NC}"
else
  echo -e "${YELLOW}Entry not found — apply aspect via Cloud Console UI:${NC}"
  echo "  1. Go to Dataplex → Manage → Lakes → sales-lake"
  echo "  2. Click 'Raw Customer Zone' → Aspects tab"
  echo "  3. +Add Aspect → select 'Protected Customer Data Aspect'"
  echo "  4. Set both flags to 'Yes'"
fi

echo -e "${GREEN}[T2 OK] Aspect type created${NC}"

# ============================================================
# Task 3: Assign IAM Role to User 2
# ============================================================
echo -e "\n${YELLOW}[Task 3] Assigning IAM to User 2...${NC}"

export USER_2="${USER_2:-user2@example.com}"   # ← SET THIS from lab credentials!

gcloud dataplex assets add-iam-policy-binding customer-engagements \
  --lake=sales-lake --zone=raw-customer-zone --location="$REGION" \
  --member="user:$USER_2" \
  --role="roles/dataplex.storageAssetOwner"

echo -e "${GREEN}[T3 OK] IAM assigned to $USER_2${NC}"

# ============================================================
# Task 4: Create & Upload Data Quality Spec
# ============================================================
echo -e "\n${YELLOW}[Task 4] Creating DQ spec file...${NC}"

export DQ_CONFIG_BUCKET="${PROJECT_ID}-dq-config"
export DQ_DATASET="orders_dq_dataset"

cat <<EOF > dq-customer-orders.yaml
rules:
  - notNull:
      column: user_id
      threshold:
        percentage: 100.0
  - notNull:
      column: order_id
      threshold:
        percentage: 100.0
EOF

gsutil cp dq-customer-orders.yaml "gs://$DQ_CONFIG_BUCKET/"

# Ensure BQ dataset exists
bq --location="$REGION" mk \
  --dataset --description="Data quality results" \
  "${PROJECT_ID}:${DQ_DATASET}" 2>/dev/null || true

echo -e "${GREEN}[T4 OK] DQ spec uploaded to gs://$DQ_CONFIG_BUCKET/dq-customer-orders.yaml${NC}"

# ============================================================
# Task 5: Define & Run Data Quality Job
# ============================================================
echo -e "\n${YELLOW}[Task 5] Submitting data quality job...${NC}"

# Find Compute Engine default service account
SA_EMAIL=$(gcloud iam service-accounts list \
  --format="value(email)" \
  --filter="displayName~Compute" \
  --limit=1 2>/dev/null)
[ -z "$SA_EMAIL" ] && SA_EMAIL="${PROJECT_ID}-compute@developer.gserviceaccount.com"

# Create DQ job config
cat <<EOF > dq-job-config.json
{
  "dataQualitySpec": {
    "rules": [
      {
        "column": "user_id",
        "notNull": {"threshold": {"percentage": 100.0}}
      },
      {
        "column": "order_id",
        "notNull": {"threshold": {"percentage": 100.0}}
      }
    ]
  },
  "dataSource": "projects/$PROJECT_ID/datasets/customer_orders/tables/ordered_items",
  "resultTable": {
    "projectId": "$PROJECT_ID",
    "datasetId": "${DQ_DATASET}",
    "tableId": "results"
  },
  "triggerSpec": {"type": "ON_DEMAND"}
}
EOF

# Submit via Dataplex DataScan API
curl -s -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  "https://dataplex.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/dataScans?dataScanId=customer-orders-data-quality-job" \
  -d @- <<EOF
{
  "displayName": "customer-orders-data-quality-job",
  "dataQualitySpec": {
    "rules": [
      {
        "column": "user_id",
        "notNull": {"threshold": {"percentage": 100.0}},
        "dimension": "COMPLETENESS"
      },
      {
        "column": "order_id",
        "notNull": {"threshold": {"percentage": 100.0}},
        "dimension": "COMPLETENESS"
      }
    ]
  },
  "data": {
    "entity": "projects/$PROJECT_ID/datasets/customer_orders/tables/ordered_items"
  },
  "dataQualityResult": {
    "destinationTable": "projects/$PROJECT_ID/datasets/${DQ_DATASET}/tables/results"
  },
  "executionSpec": {
    "trigger": "ON_DEMAND"
  },
  "serviceAccount": "$SA_EMAIL"
}
EOF

# Also try the gcloud approach if available
gcloud dataplex data-scans create customer-orders-data-quality-job \
  --location="$REGION" \
  --data-quality \
  --data-source-entity="projects/$PROJECT_ID/datasets/customer_orders/tables/ordered_items" \
  --trigger-type=on-demand \
  --project="$PROJECT_ID" 2>/dev/null || true

echo -e "\n${YELLOW}Running DQ job...${NC}"
curl -s -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://dataplex.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/dataScans/customer-orders-data-quality-job:run" > /dev/null 2>&1 || true

echo -e "${GREEN}[T5 OK] DQ job submitted${NC}"

# ============================================================
# Summary
# ============================================================
echo -e "\n${GREEN}============================================================"
echo "  GSP514 — Tasks submitted! Check progress in Qwiklabs."
echo "============================================================${NC}"
echo ""
echo "  Resources created:"
echo "  ├─ Lake:        sales-lake"
echo "  ├─ Zones:       raw-customer-zone + curated-customer-zone"
echo "  ├─ Assets:      customer-engagements (GCS)"
echo "  │               customer-orders (BQ)"
echo "  ├─ Aspect:      protected-customer-data-aspect"
echo "  ├─ DQ YAML:     gs://$DQ_CONFIG_BUCKET/dq-customer-orders.yaml"
echo "  └─ DQ Job:      customer-orders-data-quality-job"
echo ""
echo -e "${YELLOW}Don't forget to:${NC}"
echo "  export USER_2=<user-2-email-from-lab> && source solve.sh"
echo ""
