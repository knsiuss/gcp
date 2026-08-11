#!/bin/bash
# ============================================================================
# GSP510 - Manage Kubernetes in Google Cloud: Challenge Lab
# Full solver for all 6 tasks.
#
# Usage (in the lab's Cloud Shell):
#   git clone https://github.com/knsiuss/gcp.git gcp-labs
#   cd gcp-labs/gke-manage-kubernetes-gsp510
#   chmod +x solve_gsp510.sh
#   ./solve_gsp510.sh
#   -> prompts for PROJECT_ID, CLUSTER_NAME, REGION, ZONE, NAMESPACE_NAME,
#      REPO_NAME, SERVICE_NAME (from the lab page, "input method")
# ============================================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

ACTIVE_ACCOUNT=$(gcloud auth list --format="value(account)" 2>/dev/null | head -1)
[ -n "$ACTIVE_ACCOUNT" ] && gcloud config set account "$ACTIVE_ACCOUNT" --quiet 2>/dev/null || true

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP510 - Manage Kubernetes in Google Cloud: Challenge Lab Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"

# --- Input method: collect all dynamic values -------------------------------
ask() { local label="$1" def="$2"; local v; printf "${YELLOW}%s${NC} ${CYAN}[default: %s]${NC}: " "$label" "$def"; read -p "" v; echo "${v:-$def}"; }

DEFAULT_PROJECT=$(gcloud config get-value project 2>/dev/null)
PROJECT_ID=$(ask "Enter PROJECT_ID" "$DEFAULT_PROJECT")
CLUSTER_NAME=$(ask "Enter CLUSTER_NAME (cluster)" "$CLUSTER_NAME")
REGION=$(ask "Enter REGION" "us-east1")
ZONE=$(ask "Enter ZONE" "us-east1-b")
NAMESPACE_NAME=$(ask "Enter NAMESPACE_NAME" "${NAMESPACE_NAME:-gmp-marketings-demo}")
REPO_NAME=$(ask "Enter REPO_NAME" "${REPO_NAME:-hello-repo}")
SERVICE_NAME=$(ask "Enter SERVICE_NAME (service from Task 6)" "${SERVICE_NAME:-helloweb-service}")

export PROJECT_ID REGION ZONE NAMESPACE_NAME REPO_NAME SERVICE_NAME CLUSTER_NAME
if [ -n "$PROJECT_ID" ]; then gcloud config set project "$PROJECT_ID" --quiet 2>/dev/null || true; fi
gcloud config set compute/zone "$ZONE" --quiet 2>/dev/null || true
gcloud config set compute/region "$REGION" --quiet 2>/dev/null || true

echo -e "${CYAN}[*] Project: $PROJECT_ID | Cluster: $CLUSTER_NAME | Region: $REGION | Zone: $ZONE${NC}"
echo -e "${CYAN}[*] Namespace: $NAMESPACE_NAME | Repo: $REPO_NAME | Service: $SERVICE_NAME${NC}"

# ============================================================================
# Task 1: Create a GKE cluster (autoscaler, 3 nodes, min 2 / max 6)
# ============================================================================
echo -e "\n${YELLOW}[Task 1] Creating GKE cluster $CLUSTER_NAME...${NC}"
if gcloud container clusters describe "$CLUSTER_NAME" --zone="$ZONE" >/dev/null 2>&1; then
  echo "  Cluster already exists."
else
  gcloud beta container clusters create "$CLUSTER_NAME" \
    --zone="$ZONE" \
    --release-channel=regular \
    --num-nodes=3 \
    --enable-autoscaling --min-nodes=2 --max-nodes=6 \
    --quiet --no-user-output-enabled 2>/dev/null \
    || gcloud beta container clusters create "$CLUSTER_NAME" \
         --zone="$ZONE" --release-channel=regular --num-nodes=3 \
         --enable-autoscaling --min-nodes=2 --max-nodes=6
  echo -e "${GREEN}  [OK] Cluster created.${NC}"
fi
gcloud container clusters get-credentials "$CLUSTER_NAME" --zone="$ZONE" --quiet
echo -e "\n${GREEN}  ==> Task 1 DONE - check progress.${NC}"

# ============================================================================
# Task 2: Enable Managed Prometheus + namespace + sample app + pod monitoring
# ============================================================================
echo -e "\n${YELLOW}[Task 2] Enabling Managed Prometheus on the cluster...${NC}"
# Managed Prometheus can only be toggled at create time; if not enabled, recreate-free path: enable via update on the default pool is not supported, so if missing we add it with a cluster update trick is not available -> use console guidance.
gcloud beta container clusters update "$CLUSTER_NAME" --zone="$ZONE" --enable-managed-prometheus --quiet 2>/dev/null \
  && echo -e "${GREEN}  [OK] Managed Prometheus enabled (update).${NC}" \
  || echo -e "${YELLOW}  Note: if Managed Prometheus is required to show as enabled, recreate the cluster with --enable-managed-prometheus (Task 1). Proceeding with sample app...${NC}"

echo -e "\n${YELLOW}[Task 2 cont.] Creating namespace $NAMESPACE_NAME...${NC}"
kubectl create ns "$NAMESPACE_NAME" 2>/dev/null || echo "  Namespace already exists."

echo -e "\n${YELLOW}[Task 2 cont.] Downloading + patching prometheus-app.yaml...${NC}"
cd "$HOME"
gcloud storage cp gs://spls/gsp510/prometheus-app.yaml . 2>/dev/null
sed -i 's|<todo>|nilebox/prometheus-example-app:latest|g' prometheus-app.yaml
kubectl -n "$NAMESPACE_NAME" apply -f prometheus-app.yaml

echo -e "\n${YELLOW}[Task 2 cont.] Downloading + patching pod-monitoring.yaml...${NC}"
gcloud storage cp gs://spls/gsp510/pod-monitoring.yaml . 2>/dev/null
sed -i 's|<todo>|prometheus-test|g' pod-monitoring.yaml
sed -i 's|interval: <todo>|interval: 30s|g' pod-monitoring.yaml

# Ensure the labels/selectors inside match per lab spec
sed -i 's|app.kubernetes.io/name: <todo>|app.kubernetes.io/name: prometheus-test|g; s|app: <todo>|app: prometheus-test|g' pod-monitoring.yaml
kubectl -n "$NAMESPACE_NAME" apply -f pod-monitoring.yaml
kubectl get podmonitoring -A || true
echo -e "\n${GREEN}  ==> Task 2 DONE (sample prometheus app + pod monitoring) - check progress.${NC}"

# ============================================================================
# Task 3: Deploy the helloweb-deployment manifest (will show InvalidImageName)
# ============================================================================
echo -e "\n${YELLOW}[Task 3] Downloading hello-app + deploying manifest...${NC}"
cd "$HOME"
gcloud storage cp -r gs://spls/gsp510/hello-app/ .
cp -r hello-app/* "$HOME/" 2>/dev/null || true

# The repo may already be checked out; ensure we are in the right dir
MANIFEST="$(find "$HOME" -name helloweb-deployment.yaml -path '*manifests*' 2>/dev/null | head -1)"
[ -z "$MANIFEST" ] && MANIFEST="$HOME/hello-app/manifests/helloweb-deployment.yaml"
echo "  Using manifest: $MANIFEST"

kubectl -n "$NAMESPACE_NAME" apply -f "$MANIFEST" 2>/dev/null \
  || kubectl --namespace="$NAMESPACE_NAME" create -f "$MANIFEST"
kubectl -n "$NAMESPACE_NAME" get deployments
echo -e "${YELLOW}  Expected: helloweb pod with InvalidImageName error (image <todo>).${NC}"
echo -e "${YELLOW}  NOTE: Do NOT fix the image yet - Task 4 needs the error in logs.${NC}"
echo -e "\n${GREEN}  ==> Task 3 DONE - check progress.${NC}"

# ============================================================================
# Task 4: Create a logs-based metric + alerting policy
# ============================================================================
echo -e "\n${YELLOW}[Task 4] Creating logs-based metric pod-image-errors...${NC}"
gcloud logging metrics create pod-image-errors \
  --description="Errors when pulling pod images (InvalidImageName)" \
  --log-filter='severity>=ERROR AND resource.type="k8s_container"' \
  --quiet 2>/dev/null \
  || echo "  Metric may already exist."

echo -e "\n${YELLOW}[Task 4 cont.] Creating alerting policy 'Pod Error Alert'...${NC}"
cat > "$HOME/pod-error-policy.json" <<'EOF'
{
  "display_name": "Pod Error Alert",
  "combiner": "OR",
  "conditions": [
    {
      "display_name": "Pod Error Conditions",
      "condition_threshold": {
        "filter": "metric.type=\"logging.googleapis.com/user/pod-image-errors\"",
        "aggregations": [
          {
            "alignment_period": "600s",
            "per_series_aligner": "ALIGN_COUNT",
            "cross_series_reducer": "REDUCE_SUM"
          }
        ],
        "comparison": "COMPARISON_GT",
        "threshold_value": 0,
        "duration": "0s",
        "trigger": { "count": 1 }
      }
    }
  ],
  "notification_channels": []
}
EOF
gcloud alpha monitoring policies create --policy-from-file="$HOME/pod-error-policy.json" --quiet 2>/dev/null \
  || gcloud monitoring policies create --policy-from-file="$HOME/pod-error-policy.json" --quiet 2>/dev/null \
  || echo -e "${YELLOW}  Alerting policy create failed via gcloud - create it in the console (See console steps below).${NC}"
echo -e "\n${GREEN}  ==> Task 4 DONE - check progress.${NC}"
echo -e "${YELLOW}  If the policy must be created in console: Monitoring > Alerting > Create policy.${NC}"
echo -e "${YELLOW}  Metric: logging.googleapis.com/user/pod-image-errors, window 10 min, count, sum,${NC}"
echo -e "${YELLOW}  above 0, name 'Pod Error Alert'.${NC}"

# ============================================================================
# Task 5: Update manifest image, delete + redeploy
# ============================================================================
echo -e "\n${YELLOW}[Task 5] Fixing image in manifest + redeploy...${NC}"
sed -i 's|image: <todo>|image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0|g; s|image: <TODO>|image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0|g' "$MANIFEST"
grep -n 'image:' "$MANIFEST"

kubectl delete deployment helloweb --namespace="$NAMESPACE_NAME" 2>/dev/null || true
kubectl -n "$NAMESPACE_NAME" apply -f "$MANIFEST"
kubectl -n "$NAMESPACE_NAME" rollout status deployment/helloweb
kubectl -n "$NAMESPACE_NAME" get deployments
echo -e "\n${GREEN}  ==> Task 5 DONE - check progress.${NC}"

# ============================================================================
# Task 6: Containerize + push to Artifact Registry + update + expose
# ============================================================================
echo -e "\n${YELLOW}[Task 6] Updating main.go to Version 2.0.0...${NC}"
APP_DIR="$HOME/hello-app"
cd "$APP_DIR"

# Version on line ~49: sed replace any 1.0.0 -> 2.0.0
grep -n 'Version:' main.go
sed -i 's/1.0.0/2.0.0/g' main.go
grep -n 'Version:' main.go

# Determine Artifact Registry location for $REPO_NAME
GCR_LOCATION=$(gcloud artifacts repositories list --filter="name:$REPO_NAME" --format='value(location)' 2>/dev/null | head -1)
[ -z "$GCR_LOCATION" ] && GCR_LOCATION="$REGION"
echo -e "${CYAN}[*] Artifact Registry location: $GCR_LOCATION${NC}"

IMAGE_NAME="${GCR_LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/hello-app:v2"
echo -e "\n${YELLOW}[Task 6 cont.] Building + pushing ${IMAGE_NAME}...${NC}"
gcloud auth configure-docker "${GCR_LOCATION}-docker.pkg.dev" --quiet
docker build -t "$IMAGE_NAME" .
docker push "$IMAGE_NAME"
echo -e "${GREEN}  [OK] v2 image pushed.${NC}"

echo -e "\n${YELLOW}[Task 6 cont.] Updating helloweb deployment to v2 image...${NC}"
CONTAINER_NAME=$(kubectl -n "$NAMESPACE_NAME" get deployment helloweb -o jsonpath='{.spec.template.spec.containers[0].name}' 2>/dev/null)
[ -z "$CONTAINER_NAME" ] && CONTAINER_NAME="helloweb"
kubectl -n "$NAMESPACE_NAME" set image deployment/helloweb "$CONTAINER_NAME"="$IMAGE_NAME"
kubectl -n "$NAMESPACE_NAME" rollout status deployment/helloweb

echo -e "\n${YELLOW}[Task 6 cont.] Exposing LoadBalancer service $SERVICE_NAME (port 8080)...${NC}"
kubectl -n "$NAMESPACE_NAME" delete service "$SERVICE_NAME" 2>/dev/null || true
kubectl -n "$NAMESPACE_NAME" expose deployment helloweb \
  --name="$SERVICE_NAME" --type=LoadBalancer \
  --port=8080 --target-port=8080

echo "  Waiting for external IP..."
LB_IP=""
for i in $(seq 1 30); do
  LB_IP=$(kubectl -n "$NAMESPACE_NAME" get svc "$SERVICE_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
  [ -n "$LB_IP" ] && break
  sleep 10
done
echo "  External IP: $LB_IP"
if [ -n "$LB_IP" ]; then
  echo "  --- Service response ---"
  curl -s "http://$LB_IP" || echo "  (page may need another minute to load)"
  echo "  ------------------------"
fi

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP510 SOLVER FINISHED - click 'Check my progress' for all 6 tasks.${NC}"
echo -e "${GREEN}======================================================================${NC}"