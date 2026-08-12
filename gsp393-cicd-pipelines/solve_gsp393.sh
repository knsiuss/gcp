#!/bin/bash
# ============================================================================
# GSP393 - Implement CI/CD Pipelines on Google Cloud: Challenge Lab
# Automated Solution Script
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
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export REGION="europe-west1"

gcloud config set compute/region $REGION --quiet
gcloud config set deploy/region $REGION --quiet

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP393 - Implement CI/CD Pipelines Challenge Lab Automated Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Active Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Project Number: ${PROJECT_NUMBER}${NC}"
echo -e "${CYAN}[*] Region:         ${REGION}${NC}"

# =========================================================================
# TASK 1: Prework - Enable APIs, IAM permissions, Storage Bucket, Repo, Clusters
# =========================================================================
echo -e "\n${YELLOW}[Task 1] Enabling APIs & Setting IAM Permissions...${NC}"
gcloud services enable \
    container.googleapis.com \
    clouddeploy.googleapis.com \
    artifactregistry.googleapis.com \
    cloudbuild.googleapis.com --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
    --role="roles/clouddeploy.jobRunner" --quiet 2>/dev/null || true

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
    --role="roles/container.developer" --quiet 2>/dev/null || true

gcloud storage buckets create gs://${PROJECT_ID}_cloudbuild --location=$REGION --project=$PROJECT_ID 2>/dev/null || \
gcloud storage buckets create gs://${PROJECT_ID}_cloudbuild --project=$PROJECT_ID 2>/dev/null || true

echo -e "\n${YELLOW}[Task 1] Creating Artifact Registry repository 'cicd-challenge'...${NC}"
gcloud artifacts repositories create cicd-challenge \
    --description="Image registry for tutorial web app" \
    --repository-format=docker \
    --location=$REGION \
    --project=$PROJECT_ID --quiet 2>/dev/null || true

echo -e "\n${YELLOW}[Task 1] Creating GKE clusters 'cd-staging' and 'cd-production'...${NC}"
gcloud container clusters create cd-staging --node-locations=europe-west1-d --num-nodes=1 --async --quiet 2>/dev/null || true
gcloud container clusters create cd-production --node-locations=europe-west1-d --num-nodes=1 --async --quiet 2>/dev/null || true

# =========================================================================
# TASK 2: Build images with Skaffold and upload to repository
# =========================================================================
echo -e "\n${YELLOW}[Task 2] Downloading codebase & building images with Skaffold...${NC}"
cd ~
rm -rf cloud-deploy-tutorials 2>/dev/null || true
git clone https://github.com/GoogleCloudPlatform/cloud-deploy-tutorials.git
cd cloud-deploy-tutorials
git checkout c3cae80 --quiet
cd tutorials/base

envsubst < clouddeploy-config/skaffold.yaml.template > web/skaffold.yaml

cd web
skaffold build --interactive=false \
    --default-repo $REGION-docker.pkg.dev/$PROJECT_ID/cicd-challenge \
    --file-output artifacts.json
cd ..

# =========================================================================
# TASK 3: Create Delivery Pipeline and Targets
# =========================================================================
echo -e "\n${YELLOW}[Task 3] Creating delivery pipeline 'web-app'...${NC}"
cp clouddeploy-config/delivery-pipeline.yaml.template clouddeploy-config/delivery-pipeline.yaml
sed -i "s/targetId: staging/targetId: cd-staging/" clouddeploy-config/delivery-pipeline.yaml
sed -i "s/targetId: prod/targetId: cd-production/" clouddeploy-config/delivery-pipeline.yaml
sed -i "/targetId: test/d" clouddeploy-config/delivery-pipeline.yaml

gcloud beta deploy apply --file=clouddeploy-config/delivery-pipeline.yaml --quiet || gcloud deploy apply --file=clouddeploy-config/delivery-pipeline.yaml --quiet

echo -e "\n${YELLOW}[Task 3] Waiting for GKE clusters 'cd-staging' and 'cd-production' to be RUNNING...${NC}"
while true; do
    ST1=$(gcloud container clusters describe cd-staging --region=$REGION --format="value(status)" 2>/dev/null || echo "PROVISIONING")
    ST2=$(gcloud container clusters describe cd-production --region=$REGION --format="value(status)" 2>/dev/null || echo "PROVISIONING")
    echo "Cluster Status -> cd-staging: $ST1 | cd-production: $ST2"
    if [ "$ST1" == "RUNNING" ] && [ "$ST2" == "RUNNING" ]; then
        echo "Both clusters are RUNNING!"
        break
    fi
    sleep 10
done

echo -e "\n${YELLOW}[Task 3] Configuring contexts & applying target definitions...${NC}"
CONTEXTS=("cd-staging" "cd-production")
for CONTEXT in ${CONTEXTS[@]}; do
    gcloud container clusters get-credentials ${CONTEXT} --region ${REGION} --quiet
    kubectl config rename-context gke_${PROJECT_ID}_${REGION}_${CONTEXT} ${CONTEXT} 2>/dev/null || true
    kubectl --context ${CONTEXT} apply -f kubernetes-config/web-app-namespace.yaml
done

envsubst < clouddeploy-config/target-staging.yaml.template > clouddeploy-config/target-cd-staging.yaml
envsubst < clouddeploy-config/target-prod.yaml.template > clouddeploy-config/target-cd-production.yaml
sed -i "s/staging/cd-staging/" clouddeploy-config/target-cd-staging.yaml
sed -i "s/prod/cd-production/" clouddeploy-config/target-cd-production.yaml

sed -i "s/{{project-id}}/$PROJECT_ID/g" clouddeploy-config/target-cd-staging.yaml
sed -i "s/\${PROJECT_ID}/$PROJECT_ID/g" clouddeploy-config/target-cd-staging.yaml
sed -i "s/{{project-id}}/$PROJECT_ID/g" clouddeploy-config/target-cd-production.yaml
sed -i "s/\${PROJECT_ID}/$PROJECT_ID/g" clouddeploy-config/target-cd-production.yaml

gcloud beta deploy apply --file clouddeploy-config/target-cd-staging.yaml --quiet || gcloud deploy apply --file clouddeploy-config/target-cd-staging.yaml --quiet
gcloud beta deploy apply --file clouddeploy-config/target-cd-production.yaml --quiet || gcloud deploy apply --file clouddeploy-config/target-cd-production.yaml --quiet

# =========================================================================
# TASK 4: Create Release web-app-001
# =========================================================================
echo -e "\n${YELLOW}[Task 4] Creating release web-app-001...${NC}"
gcloud beta deploy releases create web-app-001 \
    --delivery-pipeline web-app \
    --build-artifacts web/artifacts.json \
    --source web/ --quiet || \
gcloud deploy releases create web-app-001 \
    --delivery-pipeline web-app \
    --build-artifacts web/artifacts.json \
    --source web/ --quiet

echo "Waiting for rollout web-app-001 to cd-staging to complete..."
while true; do
    STATE=$(gcloud beta deploy rollouts list --delivery-pipeline web-app --release web-app-001 --filter="targetId:cd-staging" --format="value(state)" 2>/dev/null | head -1 || echo "")
    echo "Current rollout state: $STATE"
    if [ "$STATE" == "SUCCEEDED" ] || [ "$STATE" == "SUCCESS" ]; then
        echo "Rollout to cd-staging SUCCEEDED!"
        break
    fi
    sleep 10
done

# =========================================================================
# TASK 5: Promote application to production
# =========================================================================
echo -e "\n${YELLOW}[Task 5] Promoting release web-app-001 to cd-production...${NC}"
gcloud beta deploy releases promote --delivery-pipeline web-app --release web-app-001 --quiet || \
gcloud deploy releases promote --delivery-pipeline web-app --release web-app-001 --quiet

sleep 5

gcloud beta deploy rollouts approve web-app-001-to-cd-production-0001 --delivery-pipeline web-app --release web-app-001 --quiet || \
gcloud deploy rollouts approve web-app-001-to-cd-production-0001 --delivery-pipeline web-app --release web-app-001 --quiet || true

while true; do
    PROD_STATE=$(gcloud beta deploy rollouts list --delivery-pipeline web-app --release web-app-001 --filter="targetId:cd-production" --format="value(state)" 2>/dev/null | head -1 || echo "")
    echo "Production rollout state: $PROD_STATE"
    if [ "$PROD_STATE" == "SUCCEEDED" ] || [ "$PROD_STATE" == "SUCCESS" ]; then
        echo "Rollout to cd-production SUCCEEDED!"
        break
    fi
    sleep 10
done

# =========================================================================
# TASK 6: Make a change to the application and redeploy (web-app-002)
# =========================================================================
echo -e "\n${YELLOW}[Task 6] Modifying app.go and creating release web-app-002...${NC}"
sed -i 's/leeroy app/leeroooooy app v2!!/g' web/leeroy-app/app.go 2>/dev/null || true

cd web
skaffold build --interactive=false \
    --default-repo $REGION-docker.pkg.dev/$PROJECT_ID/cicd-challenge \
    --file-output artifacts.json
cd ..

gcloud beta deploy releases create web-app-002 \
    --delivery-pipeline web-app \
    --build-artifacts web/artifacts.json \
    --source web/ --quiet || \
gcloud deploy releases create web-app-002 \
    --delivery-pipeline web-app \
    --build-artifacts web/artifacts.json \
    --source web/ --quiet

while true; do
    STATE2=$(gcloud beta deploy rollouts list --delivery-pipeline web-app --release web-app-002 --filter="targetId:cd-staging" --format="value(state)" 2>/dev/null | head -1 || echo "")
    echo "Rollout web-app-002 to cd-staging state: $STATE2"
    if [ "$STATE2" == "SUCCEEDED" ] || [ "$STATE2" == "SUCCESS" ]; then
        echo "Rollout web-app-002 to cd-staging SUCCEEDED!"
        break
    fi
    sleep 10
done

# =========================================================================
# TASK 7: Rollback The Change on cd-staging
# =========================================================================
echo -e "\n${YELLOW}[Task 7] Rolling back cd-staging to web-app-001...${NC}"
gcloud beta deploy targets rollback cd-staging --delivery-pipeline web-app --release web-app-001 --quiet || \
gcloud deploy targets rollback cd-staging --delivery-pipeline web-app --release web-app-001 --quiet || \
gcloud beta deploy releases promote --delivery-pipeline web-app --release web-app-001 --to-target cd-staging --quiet || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP393 SOLVER EXECUTED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on all tasks in Qwiklabs!${NC}"
