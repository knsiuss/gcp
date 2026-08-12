#!/bin/bash
# ============================================================================
# GSP1079 - Continuous Delivery with Google Cloud Deploy Automated Solver
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

ACTIVE_ACCOUNT=$(gcloud auth list --format="value(account)" 2>/dev/null | head -1)
if [ -n "$ACTIVE_ACCOUNT" ]; then
    gcloud config set account "$ACTIVE_ACCOUNT" --quiet 2>/dev/null || true
fi

if [ -n "$DEVSHELL_PROJECT_ID" ]; then
    gcloud config set project "$DEVSHELL_PROJECT_ID" --quiet 2>/dev/null || true
fi

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
export REGION="europe-west4"

gcloud config set compute/region $REGION --quiet
gcloud config set deploy/region $REGION --quiet

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP1079 - Cloud Deploy Automated Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Active Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Region:         ${REGION}${NC}"

# =========================================================================
# TASK 1 & 2: Enable APIs & Create 3 GKE Clusters
# =========================================================================
echo -e "\n${YELLOW}[Task 1 & 2] Enabling APIs & Creating GKE Clusters (test, staging, prod)...${NC}"
gcloud services enable \
    container.googleapis.com \
    clouddeploy.googleapis.com \
    artifactregistry.googleapis.com \
    cloudbuild.googleapis.com --quiet

gcloud container clusters create test --node-locations=europe-west4-a --num-nodes=1 --async --quiet 2>/dev/null || true
gcloud container clusters create staging --node-locations=europe-west4-a --num-nodes=1 --async --quiet 2>/dev/null || true
gcloud container clusters create prod --node-locations=europe-west4-a --num-nodes=1 --async --quiet 2>/dev/null || true

# =========================================================================
# TASK 3: Create Artifact Registry Repository
# =========================================================================
echo -e "\n${YELLOW}[Task 3] Creating Artifact Registry repository 'web-app'...${NC}"
gcloud artifacts repositories create web-app \
    --description="Image registry for tutorial web app" \
    --repository-format=docker \
    --location=$REGION \
    --project=$PROJECT_ID --quiet 2>/dev/null || true

# =========================================================================
# TASK 4: Create CloudBuild Bucket & Build container images with Skaffold
# =========================================================================
echo -e "\n${YELLOW}[Task 4] Creating Cloud Build Storage Bucket & Building images...${NC}"
gcloud storage buckets create gs://${PROJECT_ID}_cloudbuild --location=$REGION --project=$PROJECT_ID 2>/dev/null || \
gcloud storage buckets create gs://${PROJECT_ID}_cloudbuild --project=$PROJECT_ID 2>/dev/null || \
gsutil mb -l $REGION -p $PROJECT_ID gs://${PROJECT_ID}_cloudbuild 2>/dev/null || true

cd ~
rm -rf cloud-deploy-tutorials 2>/dev/null || true
git clone https://github.com/GoogleCloudPlatform/cloud-deploy-tutorials.git
cd cloud-deploy-tutorials
git checkout c3cae80 --quiet
cd tutorials/base

envsubst < clouddeploy-config/skaffold.yaml.template > web/skaffold.yaml

cd web
skaffold build --interactive=false \
    --default-repo $REGION-docker.pkg.dev/$PROJECT_ID/web-app \
    --file-output artifacts.json
cd ..

# =========================================================================
# TASK 5: Create Delivery Pipeline
# =========================================================================
echo -e "\n${YELLOW}[Task 5] Creating Cloud Deploy delivery pipeline...${NC}"
cp clouddeploy-config/delivery-pipeline.yaml.template clouddeploy-config/delivery-pipeline.yaml
gcloud beta deploy apply --file=clouddeploy-config/delivery-pipeline.yaml --quiet || gcloud deploy apply --file=clouddeploy-config/delivery-pipeline.yaml --quiet

# =========================================================================
# TASK 6: Configure Deployment Targets (Wait for GKE Clusters)
# =========================================================================
echo -e "\n${YELLOW}[Task 6] Waiting for GKE clusters to become RUNNING...${NC}"
while true; do
    TEST_ST=$(gcloud container clusters describe test --region=$REGION --format="value(status)" 2>/dev/null || echo "PROVISIONING")
    STAGING_ST=$(gcloud container clusters describe staging --region=$REGION --format="value(status)" 2>/dev/null || echo "PROVISIONING")
    PROD_ST=$(gcloud container clusters describe prod --region=$REGION --format="value(status)" 2>/dev/null || echo "PROVISIONING")
    
    echo "Cluster Statuses -> test: $TEST_ST | staging: $STAGING_ST | prod: $PROD_ST"
    if [ "$TEST_ST" == "RUNNING" ] && [ "$STAGING_ST" == "RUNNING" ] && [ "$PROD_ST" == "RUNNING" ]; then
        echo "All 3 GKE clusters are RUNNING!"
        break
    fi
    sleep 10
done

echo -e "\n${YELLOW}[Task 6] Getting credentials and configuring contexts/namespaces...${NC}"
CONTEXTS=("test" "staging" "prod")
for CONTEXT in ${CONTEXTS[@]}; do
    gcloud container clusters get-credentials ${CONTEXT} --region ${REGION} --quiet
    kubectl config rename-context gke_${PROJECT_ID}_${REGION}_${CONTEXT} ${CONTEXT} 2>/dev/null || true
    kubectl --context ${CONTEXT} apply -f kubernetes-config/web-app-namespace.yaml
done

for CONTEXT in ${CONTEXTS[@]}; do
    envsubst < clouddeploy-config/target-$CONTEXT.yaml.template > clouddeploy-config/target-$CONTEXT.yaml
    sed -i "s/{{project-id}}/$PROJECT_ID/g" clouddeploy-config/target-$CONTEXT.yaml
    sed -i "s/\${PROJECT_ID}/$PROJECT_ID/g" clouddeploy-config/target-$CONTEXT.yaml
    gcloud beta deploy apply --file clouddeploy-config/target-$CONTEXT.yaml --quiet || gcloud deploy apply --file clouddeploy-config/target-$CONTEXT.yaml --quiet
done

# =========================================================================
# TASK 7: Create Release & Rollout to test
# =========================================================================
echo -e "\n${YELLOW}[Task 7] Creating Release web-app-001...${NC}"
gcloud beta deploy releases create web-app-001 \
    --delivery-pipeline web-app \
    --build-artifacts web/artifacts.json \
    --source web/ --quiet || \
gcloud deploy releases create web-app-001 \
    --delivery-pipeline web-app \
    --build-artifacts web/artifacts.json \
    --source web/ --quiet

echo "Waiting for rollout to 'test' to complete..."
while true; do
    STATE=$(gcloud beta deploy rollouts list --delivery-pipeline web-app --release web-app-001 --format="value(state)" 2>/dev/null | head -1 || echo "")
    echo "Current rollout state: $STATE"
    if [ "$STATE" == "SUCCEEDED" ] || [ "$STATE" == "SUCCESS" ]; then
        echo "Rollout to test SUCCEEDED!"
        break
    fi
    sleep 10
done

# =========================================================================
# TASK 8: Promote to Staging
# =========================================================================
echo -e "\n${YELLOW}[Task 8] Promoting release to staging...${NC}"
gcloud beta deploy releases promote --delivery-pipeline web-app --release web-app-001 --quiet || \
gcloud deploy releases promote --delivery-pipeline web-app --release web-app-001 --quiet

echo "Waiting for rollout to 'staging' to complete..."
while true; do
    STAGING_STATE=$(gcloud beta deploy rollouts list --delivery-pipeline web-app --release web-app-001 --filter="targetId:staging" --format="value(state)" 2>/dev/null | head -1 || echo "")
    echo "Staging rollout state: $STAGING_STATE"
    if [ "$STAGING_STATE" == "SUCCEEDED" ] || [ "$STAGING_STATE" == "SUCCESS" ]; then
        echo "Rollout to staging SUCCEEDED!"
        break
    fi
    sleep 10
done

# =========================================================================
# TASK 9: Promote to Prod & Approve
# =========================================================================
echo -e "\n${YELLOW}[Task 9] Promoting release to prod & approving rollout...${NC}"
gcloud beta deploy releases promote --delivery-pipeline web-app --release web-app-001 --quiet || \
gcloud deploy releases promote --delivery-pipeline web-app --release web-app-001 --quiet

sleep 5

gcloud beta deploy rollouts approve web-app-001-to-prod-0001 --delivery-pipeline web-app --release web-app-001 --quiet || \
gcloud deploy rollouts approve web-app-001-to-prod-0001 --delivery-pipeline web-app --release web-app-001 --quiet || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP1079 SOLVER EXECUTED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on all tasks in Qwiklabs!${NC}"
