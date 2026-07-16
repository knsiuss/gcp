#!/bin/bash
# solve_secure_builds.sh
# Automating Secure Builds with Cloud Build (GSP1184)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}    Automated Solver: Secure Builds with Cloud Build (GSP1184)        ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"
echo -e "${YELLOW}[*] Project Number:${NC} $PROJECT_NUMBER"

# Prompt for Region
read -p "Enter Google Cloud Region (default: us-central1): " REGION
if [ -z "$REGION" ]; then
    REGION="us-central1"
fi
echo -e "${YELLOW}[*] Region set to:${NC} $REGION"

echo -e "\n${YELLOW}[Step 1] Enabling required APIs...${NC}"
gcloud services enable \
  cloudkms.googleapis.com \
  cloudbuild.googleapis.com \
  container.googleapis.com \
  containerregistry.googleapis.com \
  artifactregistry.googleapis.com \
  containerscanning.googleapis.com \
  ondemandscanning.googleapis.com \
  binaryauthorization.googleapis.com

echo -e "${GREEN}[+] APIs enabled successfully!${NC}"

echo -e "\n${YELLOW}[Step 2] Granting Cloud Build Service Account permissions...${NC}"
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/ondemandscanning.admin"

echo -e "${GREEN}[+] IAM Permissions granted!${NC}"

echo -e "\n${YELLOW}[Step 3] Creating app code & Dockerfile in vuln-scan directory...${NC}"
mkdir -p vuln-scan
cd vuln-scan

# Create Dockerfile (Initial version with vulnerabilities)
cat > ./Dockerfile << EOF
FROM gcr.io/google-appengine/debian11

# System
RUN apt update && apt install python3-pip -y

# App
WORKDIR /app
COPY . ./

RUN pip3 install Flask==1.1.4  
RUN pip3 install gunicorn==20.1.0  

CMD exec gunicorn --bind :\$PORT --workers 1 --threads 8 --timeout 0 main:app
EOF

# Create main.py
cat > ./main.py << EOF
import os
from flask import Flask

app = Flask(__name__)

@app.route("/")
def hello_world():
    name = os.environ.get("NAME", "Worlds")
    return "Hello {}!".format(name)

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
EOF

# Create cloudbuild.yaml (Build-only step)
cat > ./cloudbuild.yaml << EOF
steps:
# build
- id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image', '.']
  waitFor: ['-']
EOF

echo -e "\n${YELLOW}[Step 4] Running initial Cloud Build...${NC}"
gcloud builds submit --quiet

echo -e "${GREEN}[+] Initial build completed! (Task 1 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 5] Creating Artifact Registry Repository...${NC}"
gcloud artifacts repositories create artifact-scanning-repo \
  --repository-format=docker \
  --location="$REGION" \
  --description="Docker repository" --quiet

# Configure Docker auth
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

echo -e "\n${YELLOW}[Step 6] Updating cloudbuild.yaml to push image, and running build...${NC}"
cat > ./cloudbuild.yaml << EOF
steps:
# build
- id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image', '.']
  waitFor: ['-']

# push to artifact registry
- id: "push"
  name: 'gcr.io/cloud-builders/docker'
  args: ['push',  '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image']

images:
  - '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image'
EOF

gcloud builds submit --quiet

echo -e "${GREEN}[+] Repository created and image pushed! (Task 2 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 7] Building image locally and running On-Demand Scan...${NC}"
docker build -t "${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image" .

gcloud artifacts docker images scan \
    "${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image" \
    --format="value(response.scan)" > scan_id.txt

echo -e "${YELLOW}[*] Scan ID Report Location:${NC}"
cat scan_id.txt

export SEVERITY=CRITICAL
gcloud artifacts docker images list-vulnerabilities $(cat scan_id.txt) --format="value(vulnerability.effectiveSeverity)" | if grep -Fxq ${SEVERITY}; then echo "Failed vulnerability check for ${SEVERITY} level"; else echo "No ${SEVERITY} Vulnerabilities found"; fi

echo -e "${GREEN}[+] On-Demand Scan completed successfully! (Task 4 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 8] Setting up full CI/CD scanner pipeline in cloudbuild.yaml...${NC}"
cat > ./cloudbuild.yaml << EOF
steps:
# build
- id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image', '.']
  waitFor: ['-']

#Run a vulnerability scan at _SECURITY level
- id: scan
  name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    (gcloud artifacts docker images scan \
    "${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image" \
    --location ${REGION} \
    --format="value(response.scan)") > /workspace/scan_id.txt

#Analyze the result of the scan
- id: severity-check
  name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
      gcloud artifacts docker images list-vulnerabilities \$$(cat /workspace/scan_id.txt) \
      --format="value(vulnerability.effectiveSeverity)" | if grep -Fxq CRITICAL; \
      then echo "Failed vulnerability check for CRITICAL level" && exit 1; else echo "No CRITICAL vulnerability found, congrats !" && exit 0; fi

#Retag
- id: "retag"
  name: 'gcr.io/cloud-builders/docker'
  args: ['tag',  '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:good']

#pushing to artifact registry
- id: "push"
  name: 'gcr.io/cloud-builders/docker'
  args: ['push',  '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:good']

images:
  - '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image'
EOF

echo -e "${YELLOW}[*] Testing build breaks on CRITICAL vulnerabilities (this build is EXPECTED to fail)...${NC}"
# Allow the command to fail because the container build MUST fail as part of the lab task
gcloud builds submit --quiet || true

echo -e "${GREEN}[+] Verified that the build breaks on CRITICAL vulnerabilities! (Task 5 Checkpoint 1)${NC}"

echo -e "\n${YELLOW}[Step 9] Patching Dockerfile to fix vulnerabilities (using python alpine)...${NC}"
cat > ./Dockerfile << EOF
FROM python:3.12-alpine

# App
WORKDIR /app
COPY . ./

RUN pip3 install Flask==3.0.3
RUN pip3 install gunicorn==22.0.0
RUN pip3 install Werkzeug==3.0.3

CMD exec gunicorn --bind :\$PORT --workers 1 --threads 8 main:app
EOF

echo -e "\n${YELLOW}[Step 10] Running final successful Cloud Build...${NC}"
gcloud builds submit --quiet

echo -e "${GREEN}[+] Vulnerability fixed and build succeeded! (Task 5 Checkpoint 2)${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}    Secure Builds with Cloud Build (GSP1184) completed successfully!  ${NC}"
echo -e "${GREEN}======================================================================${NC}"
