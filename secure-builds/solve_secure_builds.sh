#!/bin/bash
# solve_secure_builds.sh
# Automating Secure Builds with Cloud Build (GSP1184)

# We do not use 'set -e' globally because we intentionally trigger a build failure in Task 5
# to satisfy the checkpoint "Verify that the build breaks when a CRITICAL severity vulnerability is found".

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}        Automated Solver: Secure Builds with Cloud Build (GSP1184)    ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect variables
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"
echo -e "${YELLOW}[*] Project Number:${NC} $PROJECT_NUMBER"

# Ask for Region
if [ -z "$REGION" ]; then
    read -p "Enter Google Cloud Region (e.g. us-central1): " REGION
fi

# Automatically determine scanning location (us, europe, asia)
LOCATION="us"
if [[ "$REGION" == europe-* ]]; then
    LOCATION="europe"
elif [[ "$REGION" == asia-* ]]; then
    LOCATION="asia"
fi

echo -e "${YELLOW}[*] Region:${NC} $REGION"
echo -e "${YELLOW}[*] Scanning Location:${NC} $LOCATION"

if [ -z "$REGION" ]; then
    echo -e "${RED}Error: REGION is required.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}[Step 1] Enabling Required APIs...${NC}"
gcloud services enable \
  cloudkms.googleapis.com \
  cloudbuild.googleapis.com \
  container.googleapis.com \
  containerregistry.googleapis.com \
  artifactregistry.googleapis.com \
  containerscanning.googleapis.com \
  ondemandscanning.googleapis.com \
  binaryauthorization.googleapis.com

echo -e "${GREEN}[+] APIs Enabled!${NC}"

echo -e "\n${YELLOW}[Step 2] Granting IAM roles to Cloud Build Service Account...${NC}"
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/ondemandscanning.admin"

echo -e "${GREEN}[+] Cloud Build IAM configured!${NC}"

echo -e "\n${YELLOW}[Step 3] Preparing Task 1: Build image with Cloud Build...${NC}"
# Copy vulnerable Dockerfile
cp Dockerfile.vuln Dockerfile

# Create temporary cloudbuild.yaml for Task 1 (build step only)
cat > ./cloudbuild.yaml.tmp << EOF
steps:
- id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '${REGION}-docker.pkg.dev/\${PROJECT_ID}/artifact-scanning-repo/sample-image', '.']
EOF

# Run build
gcloud builds submit --config=cloudbuild.yaml.tmp .

echo -e "${GREEN}[+] Task 1 Build completed! (Please check progress on Qwiklabs)${NC}"

echo -e "\n${YELLOW}[Step 4] Preparing Task 2: Create Artifact Registry & Push image...${NC}"
gcloud artifacts repositories create artifact-scanning-repo \
  --repository-format=docker \
  --location="$REGION" \
  --description="Docker repository" || true

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

# Create temporary cloudbuild.yaml for Task 2 (build and push steps)
cat > ./cloudbuild.yaml.tmp << EOF
steps:
- id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '${REGION}-docker.pkg.dev/\${PROJECT_ID}/artifact-scanning-repo/sample-image', '.']
- id: "push"
  name: 'gcr.io/cloud-builders/docker'
  args: ['push',  '${REGION}-docker.pkg.dev/\${PROJECT_ID}/artifact-scanning-repo/sample-image']
images:
  - '${REGION}-docker.pkg.dev/\${PROJECT_ID}/artifact-scanning-repo/sample-image'
EOF

# Run build to push
gcloud builds submit --config=cloudbuild.yaml.tmp .

echo -e "${GREEN}[+] Task 2 Build and Push completed! (Please check progress on Qwiklabs)${NC}"

echo -e "\n${YELLOW}[Step 5] Preparing Task 4: Local Docker Build and On-Demand Scanning...${NC}"
# Build locally
docker build -t "${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image" .

# Request scan
gcloud artifacts docker images scan \
    "${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image" \
    --format="value(response.scan)" > scan_id.txt

echo -e "${YELLOW}[*] Scan ID Location:${NC} $(cat scan_id.txt)"

# List vulnerabilities
gcloud artifacts docker images list-vulnerabilities $(cat scan_id.txt) || true

# Run check
export SEVERITY=CRITICAL
gcloud artifacts docker images list-vulnerabilities $(cat scan_id.txt) --format="value(vulnerability.effectiveSeverity)" | if grep -Fxq ${SEVERITY}; then echo "Failed vulnerability check for ${SEVERITY} level"; else echo "No ${SEVERITY} Vulnerabilities found"; fi

echo -e "${GREEN}[+] Task 4 On-Demand Scanning completed! (Please check progress on Qwiklabs)${NC}"

echo -e "\n${YELLOW}[Step 6] Preparing Task 5: Use Artifact Scanning in CI/CD (Intentionally failing build)...${NC}"
# Use final cloudbuild.yaml
# Rename cloudbuild.yaml.tmp to backup
rm -f cloudbuild.yaml.tmp

echo -e "${YELLOW}[*] Running build that is expected to FAIL due to CRITICAL vulnerabilities...${NC}"
gcloud builds submit --substitutions=_REGION="$REGION",_LOCATION="$LOCATION"

echo -e "${YELLOW}[*] The build above should have FAILED. Check the Cloud Build history and click 'Check my progress' on the lab page.${NC}"

echo -e "\n${YELLOW}[Step 7] Fixing the Vulnerabilities & Re-submitting build (Success run)...${NC}"
# Copy secure Dockerfile
cp Dockerfile.secure Dockerfile

# Submit build again
gcloud builds submit --substitutions=_REGION="$REGION",_LOCATION="$LOCATION"

echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}    Secure Builds Lab completed successfully! Check Qwiklabs progress.   ${NC}"
echo -e "${GREEN}======================================================================${NC}"
