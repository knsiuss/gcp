#!/bin/bash
# ============================================================================
# GSP338 - Fix Script for Task 2 and Task 4 (Target 100/100)
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
ZONE=$(gcloud compute instances list --filter="name=video-queue-monitor" --format='value(zone)' 2>/dev/null | head -1)

if [ -z "$ZONE" ]; then
  ZONE="us-east4-c"
fi

INSTANCE_ID=$(gcloud compute instances describe video-queue-monitor --zone="$ZONE" --format="value(id)" 2>/dev/null)

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP338 - Fixing Task 2 & Task 4 (Target: 100/100)${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID:  $PROJECT_ID${NC}"
echo -e "${CYAN}[*] Zone:        $ZONE${NC}"
echo -e "${CYAN}[*] Instance ID: $INSTANCE_ID${NC}"

# ============================================================================
# FIX TASK 2: Configure VM startup script & restart VM
# ============================================================================
echo -e "\n${YELLOW}[Step 1] Creating fail-safe startup script for video-queue-monitor...${NC}"

cat > /tmp/startup_gsp338_fix.sh << EOF
#!/bin/bash

# Export all required environment variables
export PROJECT_ID="${PROJECT_ID}"
export MY_PROJECT_ID="${PROJECT_ID}"
export GOOGLE_CLOUD_PROJECT="${PROJECT_ID}"
export DEVSHELL_PROJECT_ID="${PROJECT_ID}"

export GCE_INSTANCE_ID="${INSTANCE_ID}"
export MY_GCE_INSTANCE_ID="${INSTANCE_ID}"
export INSTANCE_ID="${INSTANCE_ID}"

export GCE_INSTANCE_ZONE="${ZONE}"
export MY_GCE_INSTANCE_ZONE="${ZONE}"
export ZONE="${ZONE}"

export HOME=/root
export GOCACHE=/tmp/gocache
export GOPATH=/work/go
export PATH=\$PATH:/usr/local/go/bin

# Update apt & install dependencies
apt update -y
apt install -y golang-go git wget curl

# Install Google Cloud Ops Agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install || true
service google-cloud-ops-agent start || true

# Prepare directory & Go code
mkdir -p /work/go/video
mkdir -p /work/go/cache

gsutil cp gs://spls/gsp338/video_queue/main.go /work/go/video/main.go || true

cd /work/go/video
go mod init video || true
sed -i 's/1.23.0/1.15/g' go.mod 2>/dev/null || true
sed -i 's/1.23/1.15/g' go.mod 2>/dev/null || true

go get go.opencensus.io@v0.24.0 || true
go get contrib.go.opencensus.io/exporter/stackdriver@v0.13.4 || true

pkill -f "go run" || true
pkill -f "main" || true

nohup go run /work/go/video/main.go > /tmp/goapp.log 2>&1 &
EOF

echo -e "${YELLOW}[Step 2] Updating instance metadata & resetting video-queue-monitor VM...${NC}"
gcloud compute instances add-metadata video-queue-monitor --zone="$ZONE" --metadata-from-file startup-script=/tmp/startup_gsp338_fix.sh --quiet
gcloud compute instances reset video-queue-monitor --zone="$ZONE" --quiet

# ============================================================================
# FIX TASK 4: Add charts to Media_Dashboard
# ============================================================================
echo -e "\n${YELLOW}[Step 3] Updating Media_Dashboard with required charts...${NC}"
python3 update_dashboard.py || python3 ~/gcp-labs/monitor-log-observability/update_dashboard.py || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  FIX COMPLETE!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}[!] Wait 2-3 minutes for the VM to boot and metric to report.${NC}"
echo -e "${YELLOW}[!] Then click 'Check my progress' on Task 2 and Task 4 on Qwiklabs!${NC}"
