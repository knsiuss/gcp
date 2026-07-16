#!/bin/bash
# ARC134: Configure Service Accounts and IAM Roles for Google Cloud: Challenge Lab
set -e

# Color codes for output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}Starting automated solution for ARC134...${NC}"

# Get project details
export PROJECT_ID=$(gcloud config get-value project)
export ZONE=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

if [ -z "$ZONE" ]; then
  # Fallback zone
  export ZONE="us-central1-a"
fi
export REGION=$(echo "$ZONE" | sed 's/-[a-z]$//')

# Find lab-vm zone
export LAB_VM_ZONE=$(gcloud compute instances list --filter="name=lab-vm" --format="value(zone)" --limit=1)
if [ -z "$LAB_VM_ZONE" ]; then
  export LAB_VM_ZONE=$ZONE
fi

echo -e "${GREEN}Project ID: $PROJECT_ID${NC}"
echo -e "${GREEN}Zone: $ZONE${NC}"
echo -e "${GREEN}Region: $REGION${NC}"
echo -e "${GREEN}Lab VM Zone: $LAB_VM_ZONE${NC}"

# Task 1: Enable and Explore Gemini (skip chat)
gcloud services enable cloudaisearch.googleapis.com --project=$PROJECT_ID || true

# Task 2 & 3 & 4: Executed inside lab-vm
echo -e "${YELLOW}SSH into lab-vm to perform Task 2, Task 3, and Task 4...${NC}"
gcloud compute ssh lab-vm --zone=${LAB_VM_ZONE} --quiet --command="
# Switch config to default
gcloud config configurations activate default || true

# Task 2: Create service account devops
gcloud iam service-accounts create devops --display-name='devops'

# Task 3: Grant IAM policy bindings
export PROJECT_ID=\$(gcloud config get-value project)
export SA_EMAIL=\"devops@\${PROJECT_ID}.iam.gserviceaccount.com\"

gcloud projects add-iam-policy-binding \${PROJECT_ID} \
    --member=\"serviceAccount:\${SA_EMAIL}\" \
    --role=\"roles/iam.serviceAccountUser\"

gcloud projects add-iam-policy-binding \${PROJECT_ID} \
    --member=\"serviceAccount:\${SA_EMAIL}\" \
    --role=\"roles/compute.instanceAdmin\"

# Task 4: Create vm-2 with the devops service account
gcloud compute instances create vm-2 \
    --zone=${ZONE} \
    --service-account=\${SA_EMAIL} \
    --scopes=\"https://www.googleapis.com/auth/cloud-platform\" \
    --machine-type=e2-micro
"

echo -e "${YELLOW}Waiting for vm-2 to initialize (30 seconds)...${NC}"
sleep 30

# Verify vm-2 SSH access and compute list permissions
echo -e "${YELLOW}SSH into vm-2 to verify service account access (instances list)...${NC}"
gcloud compute ssh vm-2 --zone=${ZONE} --quiet --command="gcloud compute instances list"

# Task 5: Create a custom role using a YAML file (can be done in Cloud Shell)
echo -e "${YELLOW}Task 5: Creating custom role using YAML file...${NC}"
cat << 'EOF' > role-definition.yaml
title: "Cloud SQL Connector"
description: "Allows connection to Cloud SQL instances"
stage: "GA"
includedPermissions:
- cloudsql.instances.connect
- cloudsql.instances.get
EOF

gcloud iam roles create custom_sql_role \
    --project=${PROJECT_ID} \
    --file=role-definition.yaml

# Task 6: BigQuery client library access
echo -e "${YELLOW}Task 6: Creating service account 'bigquery-qwiklab'...${NC}"
gcloud iam service-accounts create bigquery-qwiklab --display-name="bigquery-qwiklab"
export BQ_SA="bigquery-qwiklab@${PROJECT_ID}.iam.gserviceaccount.com"

echo -e "${YELLOW}Granting BigQuery permissions to service account...${NC}"
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${BQ_SA}" \
    --role="roles/bigquery.dataViewer"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${BQ_SA}" \
    --role="roles/bigquery.user"

echo -e "${YELLOW}Creating compute instance 'bigquery-instance'...${NC}"
gcloud compute instances create bigquery-instance \
    --zone=${ZONE} \
    --service-account=${BQ_SA} \
    --scopes="https://www.googleapis.com/auth/cloud-platform" \
    --machine-type=e2-micro

echo -e "${YELLOW}Waiting for bigquery-instance to initialize (30 seconds)...${NC}"
sleep 30

echo -e "${YELLOW}SSH into bigquery-instance to run BigQuery client library script...${NC}"
gcloud compute ssh bigquery-instance --zone=${ZONE} --quiet --command="
sudo apt-get update && sudo apt-get install -y python3-pip python3-pandas
pip3 install google-cloud-bigquery db-dtypes --break-system-packages || pip3 install google-cloud-bigquery db-dtypes
cat << 'EOF_PY' > query.py
from google.auth import compute_engine
from google.cloud import bigquery
credentials = compute_engine.Credentials(
    service_account_email='${BQ_SA}')
query = '''
SELECT name, SUM(number) as total_people
FROM \`bigquery-public-data.usa_names.usa_1910_2013\`
WHERE state = 'TX'
GROUP BY name, state
ORDER BY total_people DESC
LIMIT 20
'''
client = bigquery.Client(
    project='${PROJECT_ID}',
    credentials=credentials)
print(client.query(query).to_dataframe())
EOF_PY
python3 query.py
"

echo -e "${GREEN}All tasks completed successfully!${NC}"
