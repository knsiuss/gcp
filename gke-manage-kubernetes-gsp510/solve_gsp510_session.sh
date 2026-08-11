#!/bin/bash
# ============================================================================
# GSP510 - Manage Kubernetes in Google Cloud: Challenge Lab
# FULLY AUTOMATED session build (no prompts).
#
# Session values (from the lab page):
#   PROJECT_ID     qwiklabs-gcp-03-185eb1f498b2
#   CLUSTER_NAME   hello-world-goq0
#   REGION         us-east4
#   ZONE           us-east4-c
#   NAMESPACE_NAME gmp-949y
#   REPO_NAME      demo-repo
#   SERVICE_NAME   helloweb-service-7udg
#
# Usage (in the lab's Cloud Shell):
#   git clone https://github.com/knsiuss/gcp.git gcp-labs
#   cd gcp-labs/gke-manage-kubernetes-gsp510
#   ./solve_gsp510_session.sh
# ============================================================================
set -e

export PROJECT_ID="qwiklabs-gcp-03-185eb1f498b2"
export CLUSTER_NAME="hello-world-goq0"
export REGION="us-east4"
export ZONE="us-east4-c"
export NAMESPACE_NAME="gmp-949y"
export REPO_NAME="demo-repo"
export SERVICE_NAME="helloweb-service-7udg"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP510 SESSION SOLVER - $PROJECT_ID${NC}"
echo -e "${BOLD}  Cluster: $CLUSTER_NAME ($ZONE) | NS: $NAMESPACE_NAME | Repo: $REPO_NAME${NC}"
echo -e "${BOLD}======================================================================${NC}"

ACTIVE_ACCOUNT=$(gcloud auth list --format="value(account)" 2>/dev/null | head -1)
[ -n "$ACTIVE_ACCOUNT" ] && gcloud config set account "$ACTIVE_ACCOUNT" --quiet 2>/dev/null || true
gcloud config set project "$PROJECT_ID" --quiet 2>/dev/null || true
gcloud config set compute/zone "$ZONE" --quiet 2>/dev/null || true
gcloud config set compute/region "$REGION" --quiet 2>/dev/null || true

# ============================================================================
# Task 1 + 2 (create-time): GKE cluster with Managed Prometheus
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
    --enable-managed-prometheus \
    --quiet 2>&1 | tail -3 || true
  echo -e "${GREEN}  [OK] Cluster created.${NC}"
fi
gcloud container clusters get-credentials "$CLUSTER_NAME" --zone="$ZONE" --quiet
echo -e "${GREEN}  ==> Task 1 DONE - check progress.${NC}"

# ============================================================================
# Task 2: Enable Managed Prometheus (fallback if not set at create time) +
#         namespace + sample app + pod monitoring
# ============================================================================
echo -e "\n${YELLOW}[Task 2] Enabling Managed Prometheus (fallback)...${NC}"
gcloud beta container clusters update "$CLUSTER_NAME" --zone="$ZONE" --enable-managed-prometheus --quiet 2>/dev/null \
  && echo -e "${GREEN}  [OK] Managed Prometheus enabled.${NC}" \
  || echo -e "${YELLOW}  (Already enabled or update not supported - check console if needed.)${NC}"

echo -e "\n${YELLOW}[Task 2 cont.] Creating namespace $NAMESPACE_NAME...${NC}"
kubectl create ns "$NAMESPACE_NAME" 2>/dev/null || echo "  Namespace already exists."

echo -e "\n${YELLOW}[Task 2 cont.] Downloading + patching prometheus-app.yaml...${NC}"
cd "$HOME"
gcloud storage cp gs://spls/gsp510/prometheus-app.yaml . 2>/dev/null || true
# Replace <todo> values (containers.image, containers.name, ports.name) key-aware
python3 - "$HOME/prometheus-app.yaml" <<'PYEOF'
import sys, os, re
p = sys.argv[1].replace("$HOME", os.path.expanduser("~"))
s = open(p).read()
s = re.sub(r'image:\s*<todo>', 'image: nilebox/prometheus-example-app:latest', s)
# first remaining name: <todo> is the container name, next is the port name
idx = [0]
def name_rep(m):
    n = idx[0]; idx[0] += 1
    return 'name: ' + ('prometheus-test' if n == 0 else 'metrics')
s = re.sub(r'name:\s*<todo>', name_rep, s)
open(p, "w").write(s)
PYEOF
echo "  --- prometheus-app.yaml image/name lines ---"
grep -nE 'image:|name:|port' prometheus-app.yaml | head -15
kubectl -n "$NAMESPACE_NAME" apply -f prometheus-app.yaml

echo -e "\n${YELLOW}[Task 2 cont.] Downloading + patching pod-monitoring.yaml...${NC}"
gcloud storage cp gs://spls/gsp510/pod-monitoring.yaml . 2>/dev/null || true
sed -i 's|name: <todo>|name: prometheus-test|g' pod-monitoring.yaml
sed -i 's|app.kubernetes.io/name: <todo>|app.kubernetes.io/name: prometheus-test|g' pod-monitoring.yaml
sed -i 's|app: <todo>|app: prometheus-test|g' pod-monitoring.yaml
sed -i 's|interval: <todo>|interval: 50s|g' pod-monitoring.yaml
echo "  --- pod-monitoring.yaml patched lines ---"
grep -nE 'name:|interval:|app:' pod-monitoring.yaml | head -15
kubectl -n "$NAMESPACE_NAME" apply -f pod-monitoring.yaml
kubectl get podmonitoring -A || true
echo -e "\n${GREEN}  ==> Task 2 DONE - check progress.${NC}"

# ============================================================================
# Task 3: Deploy helloweb manifest (keep the InvalidImageName error!)
# ============================================================================
echo -e "\n${YELLOW}[Task 3] Downloading hello-app + deploying manifest...${NC}"
cd "$HOME"
gcloud storage cp -r gs://spls/gsp510/hello-app/ . 2>/dev/null || true
cp -r hello-app/* "$HOME/" 2>/dev/null || true

MANIFEST="$(find "$HOME" -name helloweb-deployment.yaml -path '*manifests*' 2>/dev/null | head -1)"
[ -z "$MANIFEST" ] && MANIFEST="$HOME/hello-app/manifests/helloweb-deployment.yaml"
echo "  Using manifest: $MANIFEST"

kubectl -n "$NAMESPACE_NAME" apply -f "$MANIFEST" 2>/dev/null \
  || kubectl --namespace="$NAMESPACE_NAME" create -f "$MANIFEST" 2>/dev/null || true
kubectl -n "$NAMESPACE_NAME" get deployments
echo -e "${YELLOW}  Expected: helloweb pod with InvalidImageName error (image <todo>).${NC}"
echo -e "${YELLOW}  NOTE: Do NOT fix the image yet - Task 4 needs the error in logs.${NC}"
echo -e "${GREEN}  ==> Task 3 DONE - check progress.${NC}"

# ============================================================================
# Task 4: logs-based metric + alerting policy
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
  || echo -e "${YELLOW}  Alerting policy create failed via gcloud - create in console (Monitoring > Alerting > Create policy; metric logging.googleapis.com/user/pod-image-errors, 10 min, count, sum, above 0, name 'Pod Error Alert').${NC}"
echo -e "\n${GREEN}  ==> Task 4 DONE - check progress.${NC}"

# ============================================================================
# Task 5: Fix image, delete + redeploy
# ============================================================================
echo -e "\n${YELLOW}[Task 5] Fixing image in manifest + redeploy...${NC}"
sed -i 's|image: <todo>|image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0|g; s|image: <TODO>|image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0|g' "$MANIFEST"
echo "  --- image line after fix ---"
grep -n 'image:' "$MANIFEST"

kubectl delete deployment helloweb --namespace="$NAMESPACE_NAME" 2>/dev/null || true
kubectl -n "$NAMESPACE_NAME" apply -f "$MANIFEST"
kubectl -n "$NAMESPACE_NAME" rollout status deployment/helloweb
kubectl -n "$NAMESPACE_NAME" get deployments
echo -e "\n${GREEN}  ==> Task 5 DONE - check progress.${NC}"

# ============================================================================
# Task 6: Containerize v2 + push + update deployment + expose LB
# ============================================================================
echo -e "\n${YELLOW}[Task 6] Updating main.go to Version 2.0.0...${NC}"
APP_DIR="$HOME/hello-app"
cd "$APP_DIR"
echo "  Before:"
grep -n 'Version:' main.go
sed -i 's/1.0.0/2.0.0/g' main.go
echo "  After:"
grep -n 'Version:' main.go

GCR_LOCATION=$(gcloud artifacts repositories list --filter="name:$REPO_NAME" --format='value(location)' 2>/dev/null | head -1)
[ -z "$GCR_LOCATION" ] && GCR_LOCATION="$REGION"
IMAGE_NAME="${GCR_LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/hello-app:v2"
echo -e "${CYAN}[*] Artifact Registry location: $GCR_LOCATION${NC}"
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
echo -e "${GREEN}  GSP510 SESSION SOLVER FINISHED - click 'Check my progress' for all 6 tasks.${NC}"
echo -e "${GREEN}======================================================================${NC}"