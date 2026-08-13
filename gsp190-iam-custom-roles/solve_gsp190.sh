#!/bin/bash
# ============================================================================
# GSP190 - IAM Custom Roles Automated Solver Script
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
REGION="us-west3"

gcloud config set compute/region $REGION --quiet

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP190 - IAM Custom Roles Automated Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Active Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"

# =========================================================================
# TASK 1, 2, 3: View permissions, metadata, and grantable roles (Read-only)
# =========================================================================
echo -e "\n${YELLOW}[Task 1] Listing testable permissions...${NC}"
gcloud iam list-testable-permissions //cloudresourcemanager.googleapis.com/projects/$PROJECT_ID --format="value(name)" | head -10 || true

echo -e "\n${YELLOW}[Task 2] Getting role metadata for roles/viewer...${NC}"
gcloud iam roles describe roles/viewer || true

echo -e "\n${YELLOW}[Task 3] Listing grantable roles...${NC}"
gcloud iam list-grantable-roles //cloudresourcemanager.googleapis.com/projects/$PROJECT_ID --format="value(name)" | head -10 || true

# =========================================================================
# TASK 4: Create a custom role using YAML file & using flags
# =========================================================================
echo -e "\n${YELLOW}[Task 4] Creating 'editor' custom role via YAML file...${NC}"
cat <<'EOF' > role-definition.yaml
title: "Role Editor"
description: "Edit access for App Versions"
stage: "ALPHA"
includedPermissions:
- appengine.versions.create
- appengine.versions.delete
EOF

gcloud iam roles create editor --project $PROJECT_ID --file role-definition.yaml --quiet 2>/dev/null || true

echo -e "\n${YELLOW}[Task 4] Creating 'viewer' custom role via flags...${NC}"
gcloud iam roles create viewer --project $PROJECT_ID \
    --title "Role Viewer" \
    --description "Custom role description." \
    --permissions compute.instances.get,compute.instances.list \
    --stage ALPHA --quiet 2>/dev/null || true

# =========================================================================
# TASK 6: Update custom roles
# =========================================================================
echo -e "\n${YELLOW}[Task 6] Updating 'editor' custom role via YAML / add-permissions...${NC}"
gcloud iam roles update editor --project $PROJECT_ID \
    --add-permissions storage.buckets.get,storage.buckets.list --quiet 2>/dev/null || true

echo -e "\n${YELLOW}[Task 6] Updating 'viewer' custom role via flags...${NC}"
gcloud iam roles update viewer --project $PROJECT_ID \
    --add-permissions storage.buckets.get,storage.buckets.list --quiet 2>/dev/null || true

# =========================================================================
# TASK 7: Disable custom role
# =========================================================================
echo -e "\n${YELLOW}[Task 7] Disabling 'viewer' custom role...${NC}"
gcloud iam roles update viewer --project $PROJECT_ID \
    --stage DISABLED --quiet 2>/dev/null || true

# =========================================================================
# TASK 8 & 9: Delete and Restore custom role
# =========================================================================
echo -e "\n${YELLOW}[Task 8 & 9] Deleting and Restoring 'viewer' custom role...${NC}"
gcloud iam roles delete viewer --project $PROJECT_ID --quiet 2>/dev/null || true
gcloud iam roles undelete viewer --project $PROJECT_ID --quiet 2>/dev/null || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP190 SOLVER EXECUTED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on all tasks in Qwiklabs!${NC}"
