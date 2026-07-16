#!/bin/bash
# solve_delivery.sh
# Automating Secure Software Delivery: Challenge Lab (GSP521)

# We do not use 'set -e' globally because we intentionally trigger a build failure in Task 4
# to satisfy the checkpoint "Verify that the build breaks when a CRITICAL severity vulnerability is found".

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}        Automated Solver: Secure Software Delivery (GSP521)          ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"
echo -e "${YELLOW}[*] Project Number:${NC} $PROJECT_NUMBER"

# Ask for Region if not set
if [ -z "$REGION" ]; then
    read -p "Enter Google Cloud Region (e.g. us-central1): " REGION
fi

if [ -z "$REGION" ]; then
    echo -e "${RED}Error: REGION is required.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}[Step 1] Enabling Required APIs...${NC}"
gcloud services enable \
  cloudkms.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  container.googleapis.com \
  containerregistry.googleapis.com \
  artifactregistry.googleapis.com \
  containerscanning.googleapis.com \
  ondemandscanning.googleapis.com \
  binaryauthorization.googleapis.com

echo -e "${GREEN}[+] APIs Enabled!${NC}"

echo -e "\n${YELLOW}[Step 2] Setting up Sample App Directory...${NC}"
mkdir -p sample-app && cd sample-app
gcloud storage cp gs://spls/gsp521/* .

echo -e "\n${YELLOW}[Step 3] Creating Artifact Registry Repositories...${NC}"
gcloud artifacts repositories create artifact-scanning-repo \
  --repository-format=docker \
  --location="$REGION" \
  --description="Docker scanning repository" || true

gcloud artifacts repositories create artifact-prod-repo \
  --repository-format=docker \
  --location="$REGION" \
  --description="Docker production repository" || true

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

echo -e "${GREEN}[+] Repositories created and docker auth configured! (Task 1 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 4] Granting Initial Roles to Cloud Build Service Account...${NC}"
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/ondemandscanning.admin"

echo -e "\n${YELLOW}[Step 5] Task 2: Submitting Basic Cloud Build Pipeline...${NC}"
# Configure basic cloudbuild.yaml for Task 2 (Build and Push only)
cat > ./cloudbuild.yaml << EOF
steps:
- id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:latest', '.']
- id: "push"
  name: 'gcr.io/cloud-builders/docker'
  args: ['push', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:latest']
images:
  - '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:latest'
EOF

gcloud builds submit .

echo -e "${GREEN}[+] Task 2 Build submitted! (Please check progress on Qwiklabs for Task 2)${NC}"

echo -e "\n${YELLOW}[Step 6] Task 3: Setting up Binary Authorization...${NC}"
# Create Note JSON
cat > ./vulnerability_note.json << EOM
{
  "attestation": {
    "hint": {
      "human_readable_name": "Container Vulnerabilities attestation authority"
    }
  }
}
EOM

# Create Note
curl -X POST \
    -H "Content-Type: application/json"  \
    -H "Authorization: Bearer $(gcloud auth print-access-token)"  \
    --data-binary @./vulnerability_note.json  \
    "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/?noteId=vulnerability_note" || true

# Verify Note
curl -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/vulnerability_note"

# Create Attestor
gcloud container binauthz attestors create vulnerability-attestor \
    --attestation-authority-note=vulnerability_note \
    --attestation-authority-note-project=${PROJECT_ID} || true

# Set IAM Policy on Note
BINAUTHZ_SA_EMAIL="service-${PROJECT_NUMBER}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"

cat > ./iam_request.json << EOM
{
  "resource": "projects/${PROJECT_ID}/notes/vulnerability_note",
  "policy": {
    "bindings": [
      {
        "role": "roles/containeranalysis.notes.occurrences.viewer",
        "members": [
          "serviceAccount:${BINAUTHZ_SA_EMAIL}"
        ]
      }
    ]
  }
}
EOM

curl -X POST  \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    --data-binary @./iam_request.json \
    "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/vulnerability_note:setIamPolicy"

# Generate KMS Keyring and Key
gcloud kms keyrings create binauthz-keys --location=global || true

gcloud kms keys create lab-key \
    --keyring=binauthz-keys --location=global \
    --purpose asymmetric-signing   \
    --default-algorithm="ec-sign-p256-sha256" || true

# Link Key to Attestor
gcloud beta container binauthz attestors public-keys add  \
    --attestor="vulnerability-attestor"  \
    --keyversion-project="${PROJECT_ID}"  \
    --keyversion-location="global" \
    --keyversion-keyring="binauthz-keys" \
    --keyversion-key="lab-key" \
    --keyversion="1" || true

# Import Binary Authorization Policy
cat > binauth_policy.yaml << EOM
defaultAdmissionRule:
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  evaluationMode: REQUIRE_ATTESTATION
  requireAttestationsBy:
  - projects/${PROJECT_ID}/attestors/vulnerability-attestor
globalPolicyEvaluationMode: ENABLE
EOM

gcloud beta container binauthz policy import binauth_policy.yaml

echo -e "${GREEN}[+] Binary Authorization and KMS key setup completed! (Task 3 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 7] Task 4: Preparing Secure CI/CD Pipeline...${NC}"
# Grant additional roles to Cloud Build Service Account
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
  --role roles/binaryauthorization.attestorsViewer || true

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
  --role roles/cloudkms.signerVerifier || true

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
  --role roles/cloudkms.signerVerifier || true

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
  --role roles/containeranalysis.notes.attacher || true

# Install Custom Build Step
git clone https://github.com/GoogleCloudPlatform/cloud-builders-community.git || true
cd cloud-builders-community/binauthz-attestation
gcloud builds submit . --config cloudbuild.yaml
cd ../..
rm -rf cloud-builders-community

# Write final cloudbuild.yaml with all replaced variables
cat > ./cloudbuild.yaml << EOF
steps:

# 1. Build Step
- id: "build"
  name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:latest', '.']
  waitFor: ['-']

# 2. Push to Artifact Registry
- id: "push"
  name: 'gcr.io/cloud-builders/docker'
  args: ['push',  '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:latest']

# 3. Run a vulnerability scan
- id: scan
  name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    (gcloud artifacts docker images scan \
    ${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:latest \
    --location us \
    --format="value(response.scan)") > /workspace/scan_id.txt

# 4. Analyze the result of the scan. IF CRITICAL vulnerabilities are found, fail the build. 
- id: severity check
  name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
      gcloud artifacts docker images list-vulnerabilities \$(cat /workspace/scan_id.txt) \
      --format="value(vulnerability.effectiveSeverity)" | if grep -Fxq CRITICAL; \
      then echo "Failed vulnerability check for CRITICAL level" && exit 1; else echo \
      "No CRITICAL vulnerability found, congrats !" && exit 0; fi

# 5. Sign the image only if the previous severity check passes
- id: 'create-attestation'
  name: 'gcr.io/${PROJECT_ID}/binauthz-attestation:latest'
  args:
    - '--artifact-url'
    - '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:latest'
    - '--attestor'
    - 'projects/${PROJECT_ID}/attestors/vulnerability-attestor'
    - '--keyversion'
    - 'projects/${PROJECT_ID}/locations/global/keyRings/binauthz-keys/cryptoKeys/lab-key/cryptoKeyVersions/1'

# 6. Re-tag the image for production and push it to the production repository using the latest tag
- id: "push-to-prod"
  name: 'gcr.io/cloud-builders/docker'
  args: 
    - 'tag' 
    - '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:latest'
    - '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-prod-repo/sample-image:latest'
- id: "push-to-prod-final"
  name: 'gcr.io/cloud-builders/docker'
  args: ['push', '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-prod-repo/sample-image:latest']

# 7. Deploy to Cloud Run
- id: 'deploy-to-cloud-run'
  name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:
  - '-c'
  - |
    gcloud run deploy auth-service --image=${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-prod-repo/sample-image:latest \
    --binary-authorization=default --region=${REGION} --allow-unauthenticated

# 8. Images block
images:
  - '${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:latest'
EOF

echo -e "${YELLOW}[*] Triggering build that is expected to FAIL due to vulnerabilities...${NC}"
gcloud builds submit

echo -e "${YELLOW}[*] Check Cloud Build History to confirm build failure, then click checkpoint on Task 4.${NC}"

echo -e "\n${YELLOW}[Step 8] Task 5: Fixing the Vulnerability and Deploying...${NC}"
# Patch Dockerfile with secure settings
cat > ./Dockerfile << EOF
FROM python:3.8-alpine

# App
WORKDIR /app
COPY . ./

RUN pip3 install Flask==3.0.3
RUN pip3 install gunicorn==23.0.0
RUN pip3 install Werkzeug==3.0.4

CMD exec gunicorn --bind :\$PORT --workers 1 --threads 8 main:app
EOF

echo -e "${YELLOW}[*] Re-triggering build (should succeed)...${NC}"
gcloud builds submit

# Allow unauthenticated access for verification
gcloud beta run services add-iam-policy-binding --region="${REGION}" --member=allUsers --role=roles/run.invoker auth-service

echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}    Challenge Lab Completed! Check all checkpoints on Qwiklabs.       ${NC}"
echo -e "${GREEN}======================================================================${NC}"
