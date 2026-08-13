#!/bin/bash
# GSP364: Monitor Environments with Google Cloud Managed Service for Prometheus: Challenge Lab

# Color codes
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting GSP364 Challenge Lab solver...${NC}"

# 1. Get Project ID and Zone
export PROJECT_ID=$(gcloud config get-value project)
echo -e "${GREEN}Project ID detected: $PROJECT_ID${NC}"

# Detect Zone
export ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
if [ -z "$ZONE" ]; then
  echo -e "${YELLOW}Zone not set in config, checking metadata/defaults...${NC}"
  export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items.google-compute-default-zone)" 2>/dev/null | awk -F'/' '{print $NF}')
fi

if [ -z "$ZONE" ]; then
  # Try to list zones and pick the first active one in the region if set
  export REGION=$(gcloud config get-value compute/region 2>/dev/null)
  if [ -n "$REGION" ]; then
    export ZONE=$(gcloud compute zones list --filter="region:$REGION AND status:UP" --limit=1 --format="value(name)")
  fi
fi

if [ -z "$ZONE" ]; then
  # Fallback default
  export ZONE="us-central1-f"
fi

echo -e "${GREEN}Using Zone: $ZONE${NC}"

# 2. Deploy GKE cluster with Managed Prometheus enabled
echo -e "\n${YELLOW}[Task 1] Deploying GKE cluster 'gmp-cluster' in zone $ZONE...${NC}"
gcloud beta container clusters create gmp-cluster \
    --num-nodes=1 \
    --zone "$ZONE" \
    --enable-managed-prometheus

# Get Credentials
echo -e "\n${YELLOW}Retrieving credentials for GKE cluster...${NC}"
gcloud container clusters get-credentials gmp-cluster --zone "$ZONE"

# Create test namespace
echo -e "\n${YELLOW}Creating namespace 'gmp-test'...${NC}"
kubectl create ns gmp-test

# 3. Deploy Managed Collection
echo -e "\n${YELLOW}[Task 2] Deploying Managed Collection...${NC}"
kubectl -n gmp-test apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.3/examples/pod-monitoring.yaml

# 4. Deploy Example Application
echo -e "\n${YELLOW}[Task 3] Deploying Example Application...${NC}"
kubectl -n gmp-test apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.3/examples/example-app.yaml

# 5. Filter Exported Metrics
echo -e "\n${YELLOW}[Task 4] Filtering Exported Metrics...${NC}"
cat <<EOF > op-config.yaml
collection:
  filter:
    matchOneOf:
    - '{job="prom-example"}'
    - '{__name__=~"job:.+"}'
EOF

# Apply filter to the cluster OperatorConfig
echo -e "\n${YELLOW}Applying metrics filter to cluster OperatorConfig...${NC}"
kubectl -n gmp-public patch operatorconfig/config -p '{"collection": {"filter": {"matchOneOf": ["{job=\"prom-example\"}", "{__name__=~\"job:.+\"}"]}}}' --type=merge

# Upload op-config.yaml to Storage Bucket
echo -e "\n${YELLOW}Creating bucket and uploading config file...${NC}"
gsutil mb -p "$PROJECT_ID" "gs://$PROJECT_ID" || true
gsutil cp op-config.yaml "gs://$PROJECT_ID/"
gsutil -m acl set -R -a public-read "gs://$PROJECT_ID"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}All tasks configured! Please check your progress in Qwiklabs.${NC}"
echo -e "${GREEN}======================================================================${NC}"
