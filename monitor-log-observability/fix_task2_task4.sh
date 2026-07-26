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
# FIX TASK 2: Configure VM startup script & SSH directly to fix gRPC replace rule
# ============================================================================
echo -e "\n${YELLOW}[Step 1] Creating fail-safe startup script with gRPC replace rule...${NC}"

cat > /tmp/startup_gsp338_fix.sh << EOF
#!/bin/bash

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

apt update -y
apt install -y golang-go git wget curl

curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install || true
service google-cloud-ops-agent start || true

mkdir -p /work/go/video
mkdir -p /work/go/cache

gsutil cp gs://spls/gsp338/video_queue/main.go /work/go/video/main.go || true

cd /work/go/video
rm -f go.mod go.sum

go mod init video || true
go mod edit -replace=google.golang.org/grpc=google.golang.org/grpc@v1.29.1 || true
go get go.opencensus.io@v0.24.0 || true
go get contrib.go.opencensus.io/exporter/stackdriver@v0.13.4 || true

pkill -f "go run" || true
pkill -f "main" || true

nohup go run /work/go/video/main.go > /tmp/goapp.log 2>&1 &
EOF

echo -e "${YELLOW}[Step 2] Updating instance metadata & resetting video-queue-monitor VM...${NC}"
gcloud compute instances add-metadata video-queue-monitor --zone="$ZONE" --metadata-from-file startup-script=/tmp/startup_gsp338_fix.sh --quiet
gcloud compute instances reset video-queue-monitor --zone="$ZONE" --quiet

echo -e "${YELLOW}[Step 3] Executing direct fix via SSH to launch Go app immediately...${NC}"
sleep 15
gcloud compute ssh video-queue-monitor --zone="$ZONE" --tunnel-through-iap --quiet --command="
sudo bash -c '
  export MY_PROJECT_ID=\"$PROJECT_ID\"
  export MY_GCE_INSTANCE_ID=\"$INSTANCE_ID\"
  export MY_GCE_INSTANCE_ZONE=\"$ZONE\"
  export GOOGLE_CLOUD_PROJECT=\"$PROJECT_ID\"
  export GCE_INSTANCE_ID=\"$INSTANCE_ID\"
  export GCE_INSTANCE_ZONE=\"$ZONE\"
  export PATH=\$PATH:/usr/local/go/bin
  export GOPATH=/work/go
  export GOCACHE=/work/go/cache
  export HOME=/root

  pkill -f \"go run\" || true
  pkill -f \"main\" || true

  cd /work/go/video
  rm -f go.mod go.sum

  go mod init video
  go mod edit -replace=google.golang.org/grpc=google.golang.org/grpc@v1.29.1
  go get go.opencensus.io@v0.24.0
  go get contrib.go.opencensus.io/exporter/stackdriver@v0.13.4

  nohup go run /work/go/video/main.go > /tmp/goapp.log 2>&1 &
  sleep 4
  cat /tmp/goapp.log
'
" 2>/dev/null || true

# ============================================================================
# FIX TASK 4: Add charts to Media_Dashboard
# ============================================================================
echo -e "\n${YELLOW}[Step 4] Updating Media_Dashboard with required charts...${NC}"
python3 update_dashboard.py || python3 ~/gcp-labs/monitor-log-observability/update_dashboard.py || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  FIX COMPLETE!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}[!] Wait 2-3 minutes for the VM to report metrics.${NC}"
echo -e "${YELLOW}[!] Then click 'Check my progress' on Task 2 on Qwiklabs!${NC}"
