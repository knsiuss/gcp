#!/bin/bash
# ============================================================================
# GSP1077 - Google Kubernetes Engine Pipeline using Cloud Build Solver
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
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
REGION="europe-west1"
gcloud config set compute/region $REGION --quiet

GIT_SERVER_IP=$(gcloud compute instances describe git-server --zone=europe-west1-d --format='get(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null || echo "")

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP1077 - GKE Pipeline using Cloud Build Automated Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Active Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Project Number: ${PROJECT_NUMBER}${NC}"
echo -e "${CYAN}[*] Region:         ${REGION}${NC}"
echo -e "${CYAN}[*] Git Server IP:  ${GIT_SERVER_IP}${NC}"

# =========================================================================
# TASK 1: Initialize your lab
# =========================================================================
echo -e "\n${YELLOW}[Task 1] Enabling APIs & Creating GKE Cluster...${NC}"
gcloud services enable container.googleapis.com \
    cloudbuild.googleapis.com \
    secretmanager.googleapis.com \
    containeranalysis.googleapis.com --quiet

gcloud artifacts repositories create my-repository \
    --repository-format=docker \
    --location=$REGION \
    --project=$PROJECT_ID --quiet 2>/dev/null || true

gcloud container clusters create hello-cloudbuild \
    --num-nodes 1 \
    --region $REGION \
    --project=$PROJECT_ID --quiet 2>/dev/null || true

git config --global user.name "giteaadmin"
git config --global user.email "student@qwiklabs.net"

# =========================================================================
# TASK 2: Connect to Git repositories & Push initial app code
# =========================================================================
echo -e "\n${YELLOW}[Task 2] Setting up hello-cloudbuild-app repository...${NC}"
cd ~
mkdir -p ~/hello-cloudbuild-app
gcloud storage cp -r gs://spls/gsp1077/gke-gitops-tutorial-cloudbuild/* ~/hello-cloudbuild-app/ 2>/dev/null || true

cd ~/hello-cloudbuild-app
sed -i "s/us-central1/$REGION/g" cloudbuild.yaml 2>/dev/null || true
sed -i "s/us-central1/$REGION/g" cloudbuild-delivery.yaml 2>/dev/null || true
sed -i "s/us-central1/$REGION/g" cloudbuild-trigger-cd.yaml 2>/dev/null || true
sed -i "s/us-central1/$REGION/g" kubernetes.yaml.tpl 2>/dev/null || true

git init 2>/dev/null || true
git remote remove origin 2>/dev/null || true
git remote add origin http://${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-app.git
git branch -m main 2>/dev/null || true
git add .
git commit -m "initial commit" 2>/dev/null || true
git push -u http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-app.git main --force

# =========================================================================
# TASK 3 & 4: Create container image & CI pipeline with Cloud Build
# =========================================================================
echo -e "\n${YELLOW}[Task 3 & 4] Submitting Cloud Build container image & CI pipeline...${NC}"
cd ~/hello-cloudbuild-app
COMMIT_ID="$(git rev-parse --short=7 HEAD)"
gcloud builds submit --tag="${REGION}-docker.pkg.dev/${PROJECT_ID}/my-repository/hello-cloudbuild:${COMMIT_ID}" .

gcloud builds submit --config=cloudbuild.yaml --substitutions=SHORT_SHA=$(git rev-parse --short=7 HEAD) .

# =========================================================================
# TASK 5: Store SSH key secret in Secret Manager
# =========================================================================
echo -e "\n${YELLOW}[Task 5] Creating Secret Manager SSH Key...${NC}"
mkdir -p ~/workingdir && cd ~/workingdir
rm -f id_rsa id_rsa.pub 2>/dev/null || true
ssh-keygen -t rsa -b 4096 -N '' -f id_rsa -C "student@qwiklabs.net"

gcloud secrets create ssh_key_secret --data-file=$HOME/workingdir/id_rsa --project=$PROJECT_ID --quiet 2>/dev/null || true

gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} \
    --member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
    --role=roles/secretmanager.secretAccessor --quiet 2>/dev/null || true

# =========================================================================
# TASK 6: Create test environment and CD pipeline
# =========================================================================
echo -e "\n${YELLOW}[Task 6] Setting up hello-cloudbuild-env and CD pipeline...${NC}"

gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} \
    --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
    --role=roles/container.developer --quiet 2>/dev/null || true

mkdir -p ~/hello-cloudbuild-env
gcloud storage cp -r gs://spls/gsp1077/gke-gitops-tutorial-cloudbuild/* ~/hello-cloudbuild-env/ 2>/dev/null || true

cd ~/hello-cloudbuild-env
sed -i "s/us-central1/$REGION/g" cloudbuild.yaml 2>/dev/null || true
sed -i "s/us-central1/$REGION/g" cloudbuild-delivery.yaml 2>/dev/null || true
sed -i "s/us-central1/$REGION/g" cloudbuild-trigger-cd.yaml 2>/dev/null || true
sed -i "s/us-central1/$REGION/g" kubernetes.yaml.tpl 2>/dev/null || true

git init 2>/dev/null || true
git remote remove origin 2>/dev/null || true
git remote add origin http://${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git
git branch -m main 2>/dev/null || true
git add .
git commit -m "initial commit" 2>/dev/null || true
git push -u http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git main --force

git checkout -b production 2>/dev/null || git checkout production
git checkout -b candidate 2>/dev/null || git checkout candidate
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git production --force
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git candidate --force

# Replace cloudbuild.yaml in hello-cloudbuild-env
cd ~/hello-cloudbuild-env
cat <<'EOF' > cloudbuild.yaml
substitutions:
  _COMMIT_SHA: 'v1.0'
steps:
- name: 'gcr.io/cloud-builders/kubectl'
  id: Deploy
  args:
  - 'apply'
  - '-f'
  - 'kubernetes.yaml'
  env:
  - 'CLOUDSDK_COMPUTE_REGION=europe-west1'
  - 'CLOUDSDK_CONTAINER_CLUSTER=hello-cloudbuild'
- name: 'gcr.io/cloud-builders/gcloud'
  id: Copy to production branch
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
    set -x && \
    git clone -b production http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git prod_repo && \
    cd prod_repo && \
    git config user.email "student@qwiklabs.net" && \
    git config user.name "Cloud Build" && \
    cp ../kubernetes.yaml kubernetes.yaml && \
    git add kubernetes.yaml && \
    git commit -m "Deployed manifest from commit $_COMMIT_SHA" && \
    git push origin production
options:
  logging: CLOUD_LOGGING_ONLY
EOF
sed -i "s/\${GIT_SERVER_IP}/$GIT_SERVER_IP/g" cloudbuild.yaml

cd ~/hello-cloudbuild-env
git checkout candidate
git add cloudbuild.yaml
git commit -m "Create cloudbuild.yaml for deployment" 2>/dev/null || true
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git candidate

# Replace cloudbuild.yaml in hello-cloudbuild-app
cd ~/hello-cloudbuild-app
cat <<'EOF' > cloudbuild.yaml
substitutions:
  _SHORT_SHA: 'v1.0'
  _COMMIT_SHA: 'v1.0'
steps:
- name: 'python:3.7-slim'
  id: Test
  entrypoint: /bin/sh
  args:
  - -c
  - 'pip install flask && python test_app.py -v'
- name: 'gcr.io/cloud-builders/docker'
  id: Build
  args:
  - 'build'
  - '-t'
  - 'europe-west1-docker.pkg.dev/$PROJECT_ID/my-repository/hello-cloudbuild:$_SHORT_SHA'
  - '.'
- name: 'gcr.io/cloud-builders/docker'
  id: Push
  args:
  - 'push'
  - 'europe-west1-docker.pkg.dev/$PROJECT_ID/my-repository/hello-cloudbuild:$_SHORT_SHA'
- name: 'gcr.io/cloud-builders/gcloud'
  id: Clone env repo
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
    git clone http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git && \
    cd hello-cloudbuild-env && \
    git checkout candidate && \
    git config user.email "student@qwiklabs.net" && \
    git config user.name "Cloud Build"
- name: 'gcr.io/cloud-builders/gcloud'
  id: Generate manifest
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
    sed "s/GOOGLE_CLOUD_PROJECT/${PROJECT_ID}/g" kubernetes.yaml.tpl | \
    sed "s/COMMIT_SHA/${_SHORT_SHA}/g" > hello-cloudbuild-env/kubernetes.yaml
- name: 'gcr.io/cloud-builders/gcloud'
  id: Push manifest
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
    set -x && \
    cd hello-cloudbuild-env && \
    git add kubernetes.yaml && \
    git commit -m "Deploying image europe-west1-docker.pkg.dev/$PROJECT_ID/my-repository/hello-cloudbuild:${_SHORT_SHA} Built from commit ${_COMMIT_SHA} of repository hello-cloudbuild-app Author: $(git log --format='%an <%ae>' -n 1 HEAD)" && \
    git push origin candidate
options:
  logging: CLOUD_LOGGING_ONLY
EOF
sed -i "s/\${GIT_SERVER_IP}/$GIT_SERVER_IP/g" cloudbuild.yaml

cd ~/hello-cloudbuild-app
git add cloudbuild.yaml
git commit -m "Trigger CD pipeline" 2>/dev/null || true
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-app.git main
gcloud builds submit --config=cloudbuild.yaml --substitutions=_SHORT_SHA=$(git rev-parse --short=7 HEAD),_COMMIT_SHA=$(git rev-parse HEAD) .

# Trigger CD Deployment
cd ~/hello-cloudbuild-env
git pull http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git candidate
gcloud builds submit --config=cloudbuild.yaml --substitutions=_COMMIT_SHA=$(git rev-parse HEAD) .

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP1077 SOLVER EXECUTED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on all tasks in Qwiklabs!${NC}"
