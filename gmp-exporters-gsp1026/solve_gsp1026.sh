#!/bin/bash
# ============================================================================
# GSP1026 - Collect Metrics from Exporters using the Managed Service for
#           Prometheus
#
# Tasks covered:
#   Task 1  Deploy GKE cluster (gmp-cluster) with managed Prometheus
#   Task 2  Create gmp-test namespace
#   Task 3  Deploy the example application
#   Task 4  Configure PodMonitoring resource (prom-example)
#   Task 5  Download the prometheus binary
#   Task 6  Run the prometheus binary (background)
#   Task 7  Download + run node exporter, config.yaml, upload to GCS bucket
#
# Usage (in the lab's Cloud Shell):
#   git clone https://github.com/knsiuss/gcp.git gcp-labs
#   cd gcp-labs/gmp-exporters-gsp1026
#   chmod +x solve_gsp1026.sh
#   ./solve_gsp1026.sh
#   -> it will prompt for the ZONE (from the lab page)
# ============================================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

ACTIVE_ACCOUNT=$(gcloud auth list --format="value(account)" 2>/dev/null | head -1)
[ -n "$ACTIVE_ACCOUNT" ] && gcloud config set account "$ACTIVE_ACCOUNT" --quiet 2>/dev/null || true
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
[ -z "$PROJECT_ID" ] && PROJECT_ID="$DEVSHELL_PROJECT_ID"

CLUSTER="gmp-cluster"

# --- Prompt for the zone (lab mixes region/zone "Zone" placeholder) ---------
echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP1026 - Collect Metrics from Exporters (GMP) Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project: ${PROJECT_ID}${NC}"
echo
printf "${YELLOW}Enter the ZONE from the lab page (e.g. us-central1-a): ${NC}"
read -p "" ZONE
[ -z "$ZONE" ] && ZONE="us-central1-f"
echo -e "${CYAN}[*] Using zone: $ZONE${NC}"

gcloud config set compute/zone "$ZONE" --quiet 2>/dev/null || true

# ============================================================================
# Task 1: Deploy GKE cluster
# ============================================================================
echo -e "\n${YELLOW}[Task 1] Creating GKE cluster $CLUSTER (with managed Prometheus)...${NC}"
if gcloud container clusters describe "$CLUSTER" --zone="$ZONE" >/dev/null 2>&1; then
  echo "  Cluster '$CLUSTER' already exists."
else
  gcloud beta container clusters create "$CLUSTER" \
    --num-nodes=1 --zone="$ZONE" --enable-managed-prometheus \
    --quiet --no-user-output-enabled 2>/dev/null \
    || gcloud beta container clusters create "$CLUSTER" \
         --num-nodes=1 --zone="$ZONE" --enable-managed-prometheus
  echo -e "${GREEN}  [OK] Cluster created.${NC}"
fi

gcloud container clusters get-credentials "$CLUSTER" --zone="$ZONE" --quiet
echo -e "${GREEN}  [OK] kubeconfig updated.${NC}"
echo -e "\n${GREEN}  ==> Task 1 DONE - check progress.${NC}"

# ============================================================================
# Task 2: Set up a namespace
# ============================================================================
echo -e "\n${YELLOW}[Task 2] Creating gmp-test namespace...${NC}"
kubectl create ns gmp-test 2>/dev/null || echo "  Namespace gmp-test already exists."
kubectl get ns gmp-test
echo -e "\n${GREEN}  ==> Task 2 DONE - check progress.${NC}"

# ============================================================================
# Task 3: Deploy the example application
# ============================================================================
echo -e "\n${YELLOW}[Task 3] Deploying example application...${NC}"
kubectl -n gmp-test apply -f \
  https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.3/examples/example-app.yaml
kubectl -n gmp-test get pods
echo -e "\n${GREEN}  ==> Task 3 DONE - check progress.${NC}"

# ============================================================================
# Task 4: Configure a PodMonitoring resource
# ============================================================================
echo -e "\n${YELLOW}[Task 4] Applying PodMonitoring resource (prom-example)...${NC}"
kubectl -n gmp-test apply -f \
  https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.3/examples/pod-monitoring.yaml
kubectl get podmonitoring -A
echo -e "\n${GREEN}  ==> Task 4 DONE - check progress.${NC}"

# ============================================================================
# Task 5: Download the prometheus binary
# ============================================================================
echo -e "\n${YELLOW}[Task 5] Cloning prometheus repo + downloading GMP binary...${NC}"
if [ ! -d "$HOME/prometheus" ]; then
  git clone https://github.com/GoogleCloudPlatform/prometheus "$HOME/prometheus"
fi
cd "$HOME/prometheus"
git checkout v2.28.1-gmp.4 2>/dev/null || echo "  Note: tag v2.28.1-gmp.4 not found; using current tree."
wget -q https://storage.googleapis.com/kochasoft/gsp1026/prometheus -O "$HOME/prometheus/prometheus"
chmod a+x "$HOME/prometheus/prometheus"
echo -e "${GREEN}  [OK] prometheus binary ready.${NC}"
echo -e "\n${GREEN}  ==> Task 5 DONE - check progress.${NC}"

# ============================================================================
# Task 6: Run the prometheus binary (background)
# ============================================================================
echo -e "\n${YELLOW}[Task 6] Running prometheus binary in background...${NC}"
export PROJECT_ID
export ZONE
echo "  Project: $PROJECT_ID | Zone: $ZONE"
pkill -f 'prometheus --config.file' 2>/dev/null || true
sleep 1
nohup "$HOME/prometheus/prometheus" \
  --config.file="$HOME/prometheus/documentation/examples/prometheus.yml" \
  --export.label.project-id=$PROJECT_ID \
  --export.label.location=$ZONE \
  > "$HOME/prometheus.log" 2>&1 &
sleep 8
echo "  Log tail:"
tail -5 "$HOME/prometheus.log"
echo -e "${GREEN}  [OK] prometheus running (port 9090). Query 'up' in the console UI.${NC}"
echo -e "\n${GREEN}  ==> Task 6 DONE - check progress.${NC}"

# ============================================================================
# Task 7: Download + run node exporter, config.yaml, upload to GCS
# ============================================================================
echo -e "\n${YELLOW}[Task 7] Downloading node exporter...${NC}"
cd "$HOME"
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.3.1.linux-amd64.tar.gz >/dev/null

pkill -f node_exporter 2>/dev/null || true
sleep 1
nohup "$HOME/node_exporter-1.3.1.linux-amd64/node_exporter" > "$HOME/node_exporter.log" 2>&1 &
sleep 5
echo "  node_exporter log tail:"
tail -3 "$HOME/node_exporter.log"
echo -e "${GREEN}  [OK] node_exporter running on port 9100.${NC}"
echo -e "${YELLOW}  Note: port 9100 = metrics source used in config.yaml.${NC}"

echo -e "\n${YELLOW}[Task 7 cont.] Creating config.yaml...${NC}"
cat > "$HOME/config.yaml" <<'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: node
    static_configs:
      - targets: ['localhost:9100']
EOF

echo -e "\n${YELLOW}[Task 7 cont.] Uploading config.yaml to GCS bucket...${NC}"
gcloud storage buckets create -p "$PROJECT_ID" "gs://$PROJECT_ID" 2>/dev/null || true
gcloud storage cp "$HOME/config.yaml" "gs://$PROJECT_ID"
gsutil -m acl set -R -a public-read "gs://$PROJECT_ID" 2>/dev/null || true
echo -e "${GREEN}  [OK] config.yaml uploaded (public-read ACL = expected warning is fine).${NC}"
echo -e "\n${GREEN}  ==> Task 7 (config.yaml) DONE - check progress.${NC}"

echo -e "\n${YELLOW}[Task 7 cont.] Re-running prometheus with config.yaml (background)...${NC}"
pkill -f 'prometheus --config.file' 2>/dev/null || true
sleep 1
nohup "$HOME/prometheus/prometheus" \
  --config.file="$HOME/config.yaml" \
  --export.label.project-id=$PROJECT_ID \
  --export.label.location=$ZONE \
  > "$HOME/prometheus2.log" 2>&1 &
sleep 8
echo "  Log tail:"
tail -5 "$HOME/prometheus2.log"
echo -e "${GREEN}  [OK] prometheus re-started with config.yaml.${NC}"

echo -e "\n${YELLOW}  To view metrics: Cloud Shell -> Web Preview -> port 9090 -> query 'node_*'${NC}"
echo -e "${YELLOW}  (e.g. node_cpu_seconds_total should show a graph)${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP1026 SOLVER FINISHED - click 'Check my progress' for Tasks 1-7.${NC}"
echo -e "${GREEN}======================================================================${NC}"