#!/bin/bash
# ============================================================================
# GSP1131 - Artifact Registry: Qwik Start Automated Solution Script
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

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
LOCATION="europe-west1"
REPO_NAME="example-docker-repo"
SRC_IMAGE="us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0"
DST_IMAGE="${LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/sample-image:tag1"

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP1131 - Artifact Registry: Qwik Start Automated Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Active Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Location:       ${LOCATION}${NC}"
echo -e "${CYAN}[*] Repository:     ${REPO_NAME}${NC}"

# Task 1: Enable API & Create Docker Repository
echo -e "\n${YELLOW}[Task 1] Enabling Artifact Registry API & Creating Repository...${NC}"
gcloud services enable artifactregistry.googleapis.com --project=$PROJECT_ID --quiet

gcloud artifacts repositories create $REPO_NAME \
    --repository-format=docker \
    --location=$LOCATION \
    --description="Docker repository" \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

# Task 2: Configure Authentication
echo -e "\n${YELLOW}[Task 2] Configuring Docker Authentication...${NC}"
gcloud auth configure-docker ${LOCATION}-docker.pkg.dev --quiet

# Task 3 & 4: Pull sample image, tag & push
echo -e "\n${YELLOW}[Task 3 & 4] Pulling sample image, tagging & pushing...${NC}"
docker pull $SRC_IMAGE
docker tag $SRC_IMAGE $DST_IMAGE
docker push $DST_IMAGE

# Task 5: Pull image from Artifact Registry
echo -e "\n${YELLOW}[Task 5] Pulling image back from Artifact Registry...${NC}"
docker pull $DST_IMAGE

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP1131 SOLVER EXECUTED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on all tasks in Qwiklabs!${NC}"
