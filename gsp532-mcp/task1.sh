#!/bin/bash
# ============================================================================
# GSP532 - Task 1 Only: Set up Environment & Enable APIs
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Auto-detect project and project number
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID="$DEVSHELL_PROJECT_ID"
    gcloud config set project "$PROJECT_ID" --quiet
fi

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
MCP_SERVER_URL="https://vibe-co-zoo-mcp-server-${PROJECT_NUMBER}.us-central1.run.app/mcp/"

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP532 - Task 1: Enable APIs & Setup Environment${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Project Number: ${PROJECT_NUMBER}${NC}"

# Download code
echo -e "\n${YELLOW}[Step 1] Downloading & extracting lab code...${NC}"
cd ~
gcloud storage cp gs://${PROJECT_ID}-labconfig-bucket/labs_code.zip . 2>/dev/null || gsutil cp gs://${PROJECT_ID}-labconfig-bucket/labs_code.zip .
unzip -o labs_code.zip 2>/dev/null || true

# Create .env
echo -e "\n${YELLOW}[Step 2] Creating ~/zoo_guide_agent/.env file...${NC}"
mkdir -p ~/zoo_guide_agent
cat <<EOF > ~/zoo_guide_agent/.env
MODEL="gemini-3.5-flash"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT}"
MCP_SERVER_URL="${MCP_SERVER_URL}"
GOOGLE_GENAI_USE_ENTERPRISE=1
GOOGLE_CLOUD_PROJECT="${PROJECT_ID}"
PROJECT_NUMBER="${PROJECT_NUMBER}"
GOOGLE_CLOUD_LOCATION="us-central1"
EOF

# Enable APIs individually (ignoring agentplatform if pre-managed)
echo -e "\n${YELLOW}[Step 3] Enabling Google Cloud APIs...${NC}"
for api in artifactregistry.googleapis.com compute.googleapis.com cloudbuild.googleapis.com run.googleapis.com agentplatform.googleapis.com; do
    echo "Enabling $api..."
    gcloud services enable $api --quiet 2>/dev/null || true
done

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  TASK 1 COMPLETED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on Task 1 in Qwiklabs!${NC}"
