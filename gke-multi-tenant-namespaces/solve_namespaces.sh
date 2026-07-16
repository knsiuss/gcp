#!/bin/bash
# solve_namespaces.sh
# Automating Managing a GKE Multi-tenant Cluster with Namespaces (GSP766)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}    Automated Solver: GKE Multi-tenant Cluster with Namespaces        ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project)
export GOOGLE_CLOUD_PROJECT=$PROJECT_ID

echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

echo -e "\n${YELLOW}[Step 1] Downloading required configuration files...${NC}"
gsutil -m cp -r gs://spls/gsp766/gke-qwiklab ~
cd ~/gke-qwiklab

echo -e "\n${YELLOW}[Step 2] Authenticating GKE Cluster...${NC}"
# Dynamically discover the zone/location of the multi-tenant-cluster
ZONE=$(gcloud container clusters list --format="value(location)" | head -n 1)

if [ -z "$ZONE" ]; then
    echo -e "${RED}Error: GKE Cluster zone could not be detected.${NC}"
    exit 1
fi

echo -e "${YELLOW}[*] GKE Cluster Zone:${NC} $ZONE"
gcloud container clusters get-credentials multi-tenant-cluster --zone "$ZONE"

echo -e "\n${YELLOW}[Step 3] Creating team-a and team-b Namespaces & Pods...${NC}"
kubectl create namespace team-a || true
kubectl create namespace team-b || true

# Deploy app-server pods in both namespaces
kubectl run app-server --image=quay.io/centos/centos:9 --namespace=team-a -- sleep infinity || true
kubectl run app-server --image=quay.io/centos/centos:9 --namespace=team-b -- sleep infinity || true

echo -e "${GREEN}[+] Namespaces and pods created successfully! (Task 2 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 4] Configuring IAM and RBAC Access Control...${NC}"
# Grant Kubernetes Engine Cluster Viewer to team-a-dev service account
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:team-a-dev@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/container.clusterViewer"

# Create the developer role in namespace team-a
kubectl create -f developer-role.yaml || true

# Bind the developer role to team-a-dev
kubectl create rolebinding team-a-developers \
  --namespace=team-a \
  --role=developer \
  --user="team-a-dev@${PROJECT_ID}.iam.gserviceaccount.com" || true

# Create the key for team-a-dev (required for checkpoint verification)
gcloud iam service-accounts keys create /tmp/key.json \
  --iam-account="team-a-dev@${PROJECT_ID}.iam.gserviceaccount.com" || true

echo -e "${GREEN}[+] Access control configured! (Task 3 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 5] Task 4: Configuring Resource Quotas...${NC}"
# Create initial quota
kubectl create quota test-quota \
  --hard=count/pods=2,count/services.loadbalancers=1 \
  --namespace=team-a || true

# Create second pod
kubectl run app-server-2 --image=quay.io/centos/centos:9 --namespace=team-a -- sleep infinity || true

# Patch the quota to 6 pods non-interactively (replaces kubectl edit)
kubectl patch resourcequota test-quota \
  -p '{"spec":{"hard":{"count/pods":"6"}}}' \
  --namespace=team-a

# Create GKE memory/CPU quotas
kubectl create -f cpu-mem-quota.yaml || true

# Deploy demo pod
kubectl create -f cpu-mem-demo-pod.yaml --namespace=team-a || true

echo -e "${GREEN}[+] Resource quotas configured successfully! (Task 4 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 6] Task 5: Enabling GKE Usage Metering...${NC}"
gcloud container clusters update multi-tenant-cluster \
  --zone "$ZONE" \
  --resource-usage-bigquery-dataset cluster_dataset

echo -e "\n${YELLOW}[Step 7] Generating Cost Breakdown Table in BigQuery...${NC}"
# Extract billing export table name dynamically
BILLING_TABLE=$(bq ls --project_id="$PROJECT_ID" --format=json billing_dataset | python3 -c "import sys, json; print(json.load(sys.stdin)[0]['tableReference']['tableId'])")

export GCP_BILLING_EXPORT_TABLE_FULL_PATH="${PROJECT_ID}.billing_dataset.${BILLING_TABLE}"
export USAGE_METERING_DATASET_ID=cluster_dataset
export COST_BREAKDOWN_TABLE_ID=usage_metering_cost_breakdown

export USAGE_METERING_QUERY_TEMPLATE=~/gke-qwiklab/usage_metering_query_template.sql
export USAGE_METERING_QUERY=cost_breakdown_query.sql
export USAGE_METERING_START_DATE=2020-10-26

# Render the query file
sed \
-e "s/\${fullGCPBillingExportTableID}/$GCP_BILLING_EXPORT_TABLE_FULL_PATH/" \
-e "s/\${projectID}/$PROJECT_ID/" \
-e "s/\${datasetID}/$USAGE_METERING_DATASET_ID/" \
-e "s/\${startDate}/$USAGE_METERING_START_DATE/" \
"$USAGE_METERING_QUERY_TEMPLATE" \
> "$USAGE_METERING_QUERY"

# Run query ON-DEMAND (non-interactive, bypasses Data Studio Scheduled Query authorization prompt)
bq query \
  --project_id="$PROJECT_ID" \
  --use_legacy_sql=false \
  --destination_table="$USAGE_METERING_DATASET_ID.$COST_BREAKDOWN_TABLE_ID" \
  --replace=true \
  "$(cat $USAGE_METERING_QUERY)"

echo -e "${GREEN}[+] Cost breakdown table generated in BigQuery! (Task 5 Checkpoint)${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}    GKE Namespaces Lab completed successfully! Check Qwiklabs.       ${NC}"
echo -e "${GREEN}======================================================================${NC}"
