#!/bin/bash
# ============================================================================
# GSP532 - Task 2 Only: Perform IAM Policy Bindings
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Auto-detect project, user account, and project number
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID="$DEVSHELL_PROJECT_ID"
    gcloud config set project "$PROJECT_ID" --quiet
fi

USER_EMAIL=$(gcloud config get-value account 2>/dev/null)
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
CLOUDBUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP532 - Task 2: Perform Policy Bindings (IAM Setup)${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] User Email:     ${USER_EMAIL}${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Project Number: ${PROJECT_NUMBER}${NC}"

echo -e "\n${YELLOW}[Step 1] Binding IAM roles for User: ${USER_EMAIL}...${NC}"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="user:${USER_EMAIL}" \
    --role="roles/run.admin" --quiet

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="user:${USER_EMAIL}" \
    --role="roles/agentplatform.user" --quiet

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="user:${USER_EMAIL}" \
    --role="roles/iam.serviceAccountUser" --quiet

echo -e "\n${YELLOW}[Step 2] Binding IAM roles for Compute SA: ${COMPUTE_SA}...${NC}"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${COMPUTE_SA}" \
    --role="roles/run.admin" --quiet

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${COMPUTE_SA}" \
    --role="roles/run.invoker" --quiet

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${COMPUTE_SA}" \
    --role="roles/agentplatform.user" --quiet

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${COMPUTE_SA}" \
    --role="roles/storage.objectViewer" --quiet

echo -e "\n${YELLOW}[Step 3] Binding IAM roles for Cloud Build SA: ${CLOUDBUILD_SA}...${NC}"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${CLOUDBUILD_SA}" \
    --role="roles/run.admin" --quiet 2>/dev/null || true

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${CLOUDBUILD_SA}" \
    --role="roles/iam.serviceAccountUser" --quiet 2>/dev/null || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  TASK 2 IAM POLICY BINDINGS COMPLETED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on Task 2 in Qwiklabs!${NC}"
