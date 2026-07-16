#!/bin/bash
# solve_binauthz.sh
# Automating Gating Deployments with Binary Authorization (GSP1183)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}   Automated Solver: Gating Deployments with Binary Authorization   ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"
echo -e "${YELLOW}[*] Project Number:${NC} $PROJECT_NUMBER"

# Ask for Region and Zone if not set
if [ -z "$REGION" ]; then
    read -p "Enter Google Cloud Region (e.g. us-east1): " REGION
fi
if [ -z "$ZONE" ]; then
    read -p "Enter Google Cloud Zone (e.g. us-east1-b): " ZONE
fi

if [ -z "$REGION" ] || [ -z "$ZONE" ]; then
    echo -e "${RED}Error: REGION and ZONE are required to proceed.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}[Step 1] Enabling Required Google Cloud APIs...${NC}"
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

echo -e "\n${YELLOW}[Step 2] Creating Artifact Registry Repository...${NC}"
gcloud artifacts repositories create artifact-scanning-repo \
  --repository-format=docker \
  --location="$REGION" \
  --description="Docker repository" || true

gcloud auth configure-docker "$REGION"-docker.pkg.dev --quiet

echo -e "${GREEN}[+] Artifact Registry Repository configured!${NC}"

echo -e "\n${YELLOW}[Step 3] Building and pushing initial container image...${NC}"
gcloud builds submit . -t "${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image"

echo -e "${GREEN}[+] Initial Image built and pushed!${NC}"

echo -e "\n${YELLOW}[Step 4] Creating Attestor Note in Container Analysis...${NC}"
cat > ./vulnz_note.json << EOM
{
  "attestation": {
    "hint": {
      "human_readable_name": "Container Vulnerabilities attestation authority"
    }
  }
}
EOM

NOTE_ID=vulnz_note
curl -X POST \
    -H "Content-Type: application/json"  \
    -H "Authorization: Bearer $(gcloud auth print-access-token)"  \
    --data-binary @./vulnz_note.json  \
    "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/?noteId=${NOTE_ID}" || true

echo -e "${GREEN}[+] Attestor note registered!${NC}"

echo -e "\n${YELLOW}[Step 5] Registering Attestor in Binary Authorization...${NC}"
ATTESTOR_ID=vulnz-attestor
gcloud container binauthz attestors create $ATTESTOR_ID \
    --attestation-authority-note=$NOTE_ID \
    --attestation-authority-note-project=${PROJECT_ID} || true

echo -e "\n${YELLOW}[Step 6] Granting IAM permissions for Attestor Note access...${NC}"
BINAUTHZ_SA_EMAIL="service-${PROJECT_NUMBER}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"

cat > ./iam_request.json << EOM
{
  'resource': 'projects/${PROJECT_ID}/notes/${NOTE_ID}',
  'policy': {
    'bindings': [
      {
        'role': 'roles/containeranalysis.notes.occurrences.viewer',
        'members': [
          'serviceAccount:${BINAUTHZ_SA_EMAIL}'
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
    "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/${NOTE_ID}:setIamPolicy"

echo -e "${GREEN}[+] Attestor registered and access policy set!${NC}"

echo -e "\n${YELLOW}[Step 7] Setting up Cloud KMS keys for image signing...${NC}"
KEY_LOCATION=global
KEYRING=binauthz-keys
KEY_NAME=codelab-key
KEY_VERSION=1

gcloud kms keyrings create "${KEYRING}" --location="${KEY_LOCATION}" || true

gcloud kms keys create "${KEY_NAME}" \
    --keyring="${KEYRING}" --location="${KEY_LOCATION}" \
    --purpose asymmetric-signing   \
    --default-algorithm="ec-sign-p256-sha256" || true

gcloud beta container binauthz attestors public-keys add  \
    --attestor="${ATTESTOR_ID}"  \
    --keyversion-project="${PROJECT_ID}"  \
    --keyversion-location="${KEY_LOCATION}" \
    --keyversion-keyring="${KEYRING}" \
    --keyversion-key="${KEY_NAME}" \
    --keyversion="${KEY_VERSION}" || true

echo -e "${GREEN}[+] KMS Signing Keys added to Attestor!${NC}"

echo -e "\n${YELLOW}[Step 8] Creating GKE Cluster with Binary Authorization (Approx 3-5 mins)...${NC}"
gcloud beta container clusters create binauthz \
    --zone "$ZONE"  \
    --binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE || true

# Get cluster credentials
gcloud container clusters get-credentials binauthz --zone "$ZONE"

# Bind IAM role to let Cloud Build deploy to this cluster
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/container.developer" || true

echo -e "${GREEN}[+] GKE Cluster initialized!${NC}"

echo -e "\n${YELLOW}[Step 9] Granting IAM roles to Cloud Build Service Account...${NC}"
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

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/iam.serviceAccountUser" || true
        
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
        --role="roles/ondemandscanning.admin" || true

echo -e "${GREEN}[+] Cloud Build IAM configurations set!${NC}"

echo -e "\n${YELLOW}[Step 10] Building Custom Binary Authorization Builder Step...${NC}"
git clone https://github.com/GoogleCloudPlatform/cloud-builders-community.git || true
cd cloud-builders-community/binauthz-attestation
gcloud builds submit . --config cloudbuild.yaml
cd ../..
rm -rf cloud-builders-community

echo -e "${GREEN}[+] Custom Build Step created!${NC}"

echo -e "\n${YELLOW}[Step 11] Running Cloud Build to build and sign image:good...${NC}"
gcloud builds submit . --config=cloudbuild.yaml --substitutions=_REGION="$REGION"

echo -e "${GREEN}[+] Image built and attestation created!${NC}"

echo -e "\n${YELLOW}[Step 12] Configuring Binary Authorization policy to require attestation...${NC}"
COMPUTE_ZONE="$ZONE"
cat > binauth_policy.yaml << EOM
defaultAdmissionRule:
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  evaluationMode: REQUIRE_ATTESTATION
  requireAttestationsBy:
  - projects/${PROJECT_ID}/attestors/vulnz-attestor
globalPolicyEvaluationMode: ENABLE
clusterAdmissionRules:
  ${COMPUTE_ZONE}.binauthz:
    evaluationMode: REQUIRE_ATTESTATION
    enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
    requireAttestationsBy:
    - projects/${PROJECT_ID}/attestors/vulnz-attestor
EOM

gcloud beta container binauthz policy import binauth_policy.yaml

echo -e "${GREEN}[+] Binary Authorization policy imported!${NC}"

echo -e "\n${YELLOW}[Step 13] Deploying signed image to GKE cluster...${NC}"
CONTAINER_PATH="${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image"
DIGEST=$(gcloud container images describe ${CONTAINER_PATH}:good --format='get(image_summary.digest)')

cat > deploy.yaml << EOM
apiVersion: v1
kind: Service
metadata:
  name: deb-httpd
spec:
  selector:
    app: deb-httpd
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deb-httpd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: deb-httpd
  template:
    metadata:
      labels:
        app: deb-httpd
    spec:
      containers:
      - name: deb-httpd
        image: ${CONTAINER_PATH}@${DIGEST}
        ports:
        - containerPort: 8080
        env:
          - name: PORT
            value: "8080"
EOM

kubectl apply -f deploy.yaml

echo -e "${GREEN}[+] Signed image deployed successfully!${NC}"

echo -e "\n${YELLOW}[Step 14] Building and pushing unsigned (bad) image...${NC}"
gcloud builds submit . -t "${REGION}-docker.pkg.dev/${PROJECT_ID}/artifact-scanning-repo/sample-image:bad"

echo -e "\n${YELLOW}[Step 15] Attempting to deploy unsigned (bad) image...${NC}"
BAD_DIGEST=$(gcloud container images describe ${CONTAINER_PATH}:bad --format='get(image_summary.digest)')

cat > deploy_bad.yaml << EOM
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deb-httpd-bad
spec:
  replicas: 1
  selector:
    matchLabels:
      app: deb-httpd-bad
  template:
    metadata:
      labels:
        app: deb-httpd-bad
    spec:
      containers:
      - name: deb-httpd-bad
        image: ${CONTAINER_PATH}@${BAD_DIGEST}
        ports:
        - containerPort: 8080
        env:
          - name: PORT
            value: "8080"
EOM

echo -e "${YELLOW}Deploying bad pod (should violate policy)...${NC}"
set +e
kubectl apply -f deploy_bad.yaml
set -e

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}   Binary Authorization Lab Setup completed! Check progress in console ${NC}"
echo -e "${GREEN}======================================================================${NC}"
