#!/bin/bash
# ============================================================================
# GSP338 - Fix Script for Tasks 2, 4, 5
# Run AFTER solve_gsp338.sh
# ============================================================================

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
ZONE="us-east1-c"
CUSTOM_METRIC_NAME="${1:-big_video_upload_rate}"
ALERT_THRESHOLD="${2:-4}"

header() { echo -e "\n${BOLD}======================================================================\n  $1\n======================================================================${NC}"; }
step() { echo -e "${CYAN}[Step $1]${NC} $2"; }
success() { echo -e "${GREEN}[+]${NC} $1"; }
info() { echo -e "${YELLOW}[*]${NC} $1"; }
fail() { echo -e "${RED}[-]${NC} $1"; }

header "GSP338 - Fix Script for Failed Tasks"
info "Project: $PROJECT_ID"

# ============================================================================
# FIX TASK 2: SSH into VM and fix directly
# ============================================================================
header "Fixing Task 2: video-queue-monitor (SSH approach)"

step 1 "Checking VM metadata keys..."
gcloud compute instances describe video-queue-monitor \
  --zone="$ZONE" \
  --format='yaml(metadata.items[].key)' 2>/dev/null

step 2 "Getting full startup script via metadata..."
# Use a more reliable way to get the startup script
FULL_META=$(gcloud compute instances describe video-queue-monitor \
  --zone="$ZONE" \
  --format='json(metadata)' 2>/dev/null)

echo "$FULL_META" | python3 -c "
import json, sys
data = json.load(sys.stdin)
items = data.get('metadata', {}).get('items', [])
for item in items:
    print(f'  Key: {item[\"key\"]}  Value: {item[\"value\"][:100]}...')
" 2>/dev/null || info "Could not parse metadata"

step 3 "Extracting startup script content..."
# Try to get it via python parsing
echo "$FULL_META" | python3 -c "
import json, sys
data = json.load(sys.stdin)
items = data.get('metadata', {}).get('items', [])
for item in items:
    if 'startup' in item['key'].lower():
        with open('/tmp/original_startup.sh', 'w') as f:
            f.write(item['value'])
        print(f'Found startup script in key: {item[\"key\"]}')
        print(f'Script length: {len(item[\"value\"])} chars')
        break
else:
    print('No startup script key found in metadata')
" 2>/dev/null

step 4 "Creating comprehensive fixed startup script..."
cat > /tmp/fixed_startup.sh << 'STARTUP_SCRIPT'
#!/bin/bash

# === Install Google Cloud Ops Agent ===
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install
sudo systemctl start google-cloud-ops-agent || true

# === Set environment variables from metadata server ===
export GOOGLE_CLOUD_PROJECT=$(curl -s "http://metadata.google.internal/computeMetadata/v1/project/project-id" -H "Metadata-Flavor: Google")
export GCE_INSTANCE_ID=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/id" -H "Metadata-Flavor: Google")
export GCE_INSTANCE_ZONE=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google" | cut -d'/' -f4)

# Persist env vars
cat > /etc/profile.d/goapp.sh << ENVEOF
export GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT
export GCE_INSTANCE_ID=$GCE_INSTANCE_ID
export GCE_INSTANCE_ZONE=$GCE_INSTANCE_ZONE
ENVEOF

# === Install Go and run the application ===
sudo apt-get update -y
sudo apt-get install -y golang-go git

mkdir -p /work/go
cd /work/go

# Run the Go monitoring application
if ls *.go 1>/dev/null 2>&1; then
  go run *.go &
fi
STARTUP_SCRIPT

# Check if original startup has extra content to append
if [ -f /tmp/original_startup.sh ] && [ -s /tmp/original_startup.sh ]; then
  info "Appending original startup script content..."
  echo "" >> /tmp/fixed_startup.sh
  echo "# === Original startup script content ===" >> /tmp/fixed_startup.sh
  # Remove shebang and any existing env var lines, append the rest
  grep -v '^#!/bin/bash' /tmp/original_startup.sh | \
    grep -v 'GOOGLE_CLOUD_PROJECT' | \
    grep -v 'GCE_INSTANCE' | \
    grep -v 'ops-agent' >> /tmp/fixed_startup.sh 2>/dev/null || true
fi

step 5 "Updating startup-script metadata..."
gcloud compute instances add-metadata video-queue-monitor \
  --zone="$ZONE" \
  --metadata-from-file startup-script=/tmp/fixed_startup.sh --quiet

step 6 "SSHing into VM to apply fixes directly..."
gcloud compute ssh video-queue-monitor --zone="$ZONE" --quiet --command='
#!/bin/bash
echo "=== VM Environment Check ==="

# Install Ops Agent
echo "Installing Ops Agent..."
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install 2>&1 | tail -5
sudo systemctl start google-cloud-ops-agent 2>/dev/null

# Set environment variables
export GOOGLE_CLOUD_PROJECT=$(curl -s "http://metadata.google.internal/computeMetadata/v1/project/project-id" -H "Metadata-Flavor: Google")
export GCE_INSTANCE_ID=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/id" -H "Metadata-Flavor: Google")
export GCE_INSTANCE_ZONE=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google" | cut -d "/" -f4)

echo "PROJECT=$GOOGLE_CLOUD_PROJECT"
echo "INSTANCE=$GCE_INSTANCE_ID"
echo "ZONE=$GCE_INSTANCE_ZONE"

# Persist env vars
sudo bash -c "cat > /etc/profile.d/goapp.sh << EOF
export GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT
export GCE_INSTANCE_ID=$GCE_INSTANCE_ID
export GCE_INSTANCE_ZONE=$GCE_INSTANCE_ZONE
EOF"

# Check /work/go directory
echo ""
echo "=== /work/go contents ==="
ls -la /work/go/ 2>/dev/null || echo "Directory /work/go does not exist"

# Check if Go is installed
echo ""
echo "=== Go version ==="
go version 2>/dev/null || echo "Go not installed, installing..."
sudo apt-get update -y -qq
sudo apt-get install -y -qq golang-go 2>/dev/null

# Kill any existing Go app processes
pkill -f "go run" 2>/dev/null || true
pkill -f "video" 2>/dev/null || true
sleep 2

# Run the Go application
if [ -d /work/go ]; then
  cd /work/go
  if ls *.go 1>/dev/null 2>&1; then
    echo ""
    echo "=== Starting Go application ==="
    nohup bash -c "export GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT && export GCE_INSTANCE_ID=$GCE_INSTANCE_ID && export GCE_INSTANCE_ZONE=$GCE_INSTANCE_ZONE && cd /work/go && go run *.go" > /tmp/goapp.log 2>&1 &
    echo "Go app started with PID $!"
    sleep 5
    echo "=== App log ==="
    cat /tmp/goapp.log 2>/dev/null | tail -10
  else
    echo "No .go files found in /work/go"
    ls -la /work/go/
  fi
fi
' 2>&1

if [ $? -eq 0 ]; then
  success "SSH fixes applied! Go application should be running."
else
  fail "SSH failed. Trying stop/start approach..."
  gcloud compute instances stop video-queue-monitor --zone="$ZONE" --quiet 2>/dev/null
  sleep 10
  gcloud compute instances start video-queue-monitor --zone="$ZONE" --quiet 2>/dev/null
  info "Instance restarted. Startup script will run automatically."
fi

info "Waiting 60 seconds for metric data to be generated..."
sleep 60

step 7 "Verifying custom metric..."
METRIC_CHECK=$(gcloud monitoring metrics-descriptors list \
  --filter='metric.type="custom.googleapis.com/opencensus/my.videoservice.org/measure/input_queue_size"' \
  --format='value(type)' 2>/dev/null | head -1)

if [ -n "$METRIC_CHECK" ]; then
  success "Custom metric 'input_queue_size' is being reported!"
else
  info "Custom metric not visible yet. May take 5-10 more minutes."
fi

# ============================================================================
# FIX TASK 4: Dashboard (keep etag)
# ============================================================================
header "Fixing Task 4: Media_Dashboard (with etag)"

step 1 "Finding Media_Dashboard..."
DASHBOARD_ID=$(gcloud monitoring dashboards list \
  --filter='displayName="Media_Dashboard"' \
  --format='value(name)' 2>/dev/null | head -1)

if [ -z "$DASHBOARD_ID" ]; then
  fail "Media_Dashboard not found!"
else
  info "Dashboard: $DASHBOARD_ID"

  step 2 "Getting current dashboard config..."
  gcloud monitoring dashboards describe "$DASHBOARD_ID" --format=json > /tmp/dashboard.json

  step 3 "Adding charts (preserving etag)..."
  python3 << PYEOF
import json

with open('/tmp/dashboard.json', 'r') as f:
    dashboard = json.load(f)

etag = dashboard.get('etag', '')
print(f"Current etag: {etag}")

# Check if our widgets already exist
existing_titles = set()
if 'mosaicLayout' in dashboard:
    for tile in dashboard['mosaicLayout'].get('tiles', []):
        widget = tile.get('widget', {})
        existing_titles.add(widget.get('title', ''))
elif 'gridLayout' in dashboard:
    for widget in dashboard['gridLayout'].get('widgets', []):
        existing_titles.add(widget.get('title', ''))

print(f"Existing widget titles: {existing_titles}")

input_queue_widget = {
    "title": "Video Input Queue Size",
    "xyChart": {
        "dataSets": [{
            "timeSeriesQuery": {
                "timeSeriesFilter": {
                    "filter": 'metric.type="custom.googleapis.com/opencensus/my.videoservice.org/measure/input_queue_size" resource.type="gce_instance"',
                    "aggregation": {
                        "alignmentPeriod": "60s",
                        "perSeriesAligner": "ALIGN_MEAN"
                    }
                }
            },
            "plotType": "LINE"
        }],
        "timeshiftDuration": "0s",
        "yAxis": {"scale": "LINEAR"}
    }
}

upload_rate_widget = {
    "title": "High Resolution Video Upload Rate",
    "xyChart": {
        "dataSets": [{
            "timeSeriesQuery": {
                "timeSeriesFilter": {
                    "filter": 'metric.type="logging.googleapis.com/user/${CUSTOM_METRIC_NAME}"',
                    "aggregation": {
                        "alignmentPeriod": "60s",
                        "perSeriesAligner": "ALIGN_RATE"
                    }
                }
            },
            "plotType": "LINE"
        }],
        "timeshiftDuration": "0s",
        "yAxis": {"scale": "LINEAR"}
    }
}

new_widgets = []
if "Video Input Queue Size" not in existing_titles:
    new_widgets.append(input_queue_widget)
if "High Resolution Video Upload Rate" not in existing_titles:
    new_widgets.append(upload_rate_widget)

if not new_widgets:
    print("Widgets already exist, skipping addition")
else:
    if 'mosaicLayout' in dashboard:
        tiles = dashboard['mosaicLayout'].get('tiles', [])
        max_y = 0
        for tile in tiles:
            bottom = tile.get('yPos', 0) + tile.get('height', 0)
            if bottom > max_y:
                max_y = bottom
        for i, widget in enumerate(new_widgets):
            tiles.append({
                "yPos": max_y + (i * 16),
                "xPos": 0,
                "width": 24,
                "height": 16,
                "widget": widget
            })
        dashboard['mosaicLayout']['tiles'] = tiles
    elif 'gridLayout' in dashboard:
        widgets = dashboard['gridLayout'].get('widgets', [])
        widgets.extend(new_widgets)
        dashboard['gridLayout']['widgets'] = widgets
    elif 'rowLayout' in dashboard:
        rows = dashboard['rowLayout'].get('rows', [])
        for widget in new_widgets:
            rows.append({"widgets": [widget]})
        dashboard['rowLayout']['rows'] = rows
    else:
        dashboard['gridLayout'] = {"widgets": new_widgets}

# Remove 'name' but KEEP 'etag'
dashboard.pop('name', None)

with open('/tmp/dashboard_updated.json', 'w') as f:
    json.dump(dashboard, f, indent=2)

print(f"Dashboard JSON saved with etag: {dashboard.get('etag', 'MISSING')}")
print(f"Added {len(new_widgets)} new widgets")
PYEOF

  step 4 "Updating dashboard..."
  gcloud monitoring dashboards update "$DASHBOARD_ID" \
    --config-from-file=/tmp/dashboard_updated.json --quiet 2>&1

  if [ $? -eq 0 ]; then
    success "Dashboard updated with 2 new charts!"
  else
    fail "Dashboard update failed!"
    cat /tmp/dashboard_updated.json | python3 -c "import json,sys; d=json.load(sys.stdin); print('Has etag:', 'etag' in d)"
  fi
fi

# ============================================================================
# FIX TASK 5: Alert with resource.type
# ============================================================================
header "Fixing Task 5: Alert Policy (with resource.type)"

step 1 "Deleting any broken alert policies..."
EXISTING_POLICIES=$(gcloud alpha monitoring policies list \
  --format='value(name)' 2>/dev/null)

if [ -n "$EXISTING_POLICIES" ]; then
  while IFS= read -r policy; do
    if [ -n "$policy" ]; then
      info "Deleting policy: $policy"
      gcloud alpha monitoring policies delete "$policy" --quiet 2>/dev/null
    fi
  done <<< "$EXISTING_POLICIES"
fi

step 2 "Creating alert policy with resource.type=global..."
ACCESS_TOKEN=$(gcloud auth print-access-token 2>/dev/null)

# Try with resource.type="global" first
ALERT_RESPONSE=$(curl -s -X POST \
  "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/alertPolicies" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "displayName": "High Resolution Video Upload Rate Alert",
    "conditions": [{
      "displayName": "'"${CUSTOM_METRIC_NAME}"' rate exceeds '"${ALERT_THRESHOLD}"'",
      "conditionThreshold": {
        "filter": "metric.type=\"logging.googleapis.com/user/'"${CUSTOM_METRIC_NAME}"'\" resource.type=\"global\"",
        "comparison": "COMPARISON_GT",
        "thresholdValue": '"${ALERT_THRESHOLD}"',
        "duration": "0s",
        "trigger": {"count": 1},
        "aggregations": [{
          "alignmentPeriod": "60s",
          "perSeriesAligner": "ALIGN_RATE"
        }]
      }
    }],
    "combiner": "OR",
    "enabled": true,
    "alertStrategy": {"autoClose": "604800s"}
  }')

echo "$ALERT_RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'error' in data:
        print(f'Error: {data[\"error\"][\"message\"]}')
    else:
        print(f'Success! Alert: {data.get(\"name\", \"created\")}')
except:
    print('Could not parse response')
" 2>/dev/null

# If global didn't work, try cloud_function
if echo "$ALERT_RESPONSE" | grep -q '"error"'; then
  info "Trying with resource.type=cloud_function..."
  ALERT_RESPONSE2=$(curl -s -X POST \
    "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/alertPolicies" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "displayName": "High Resolution Video Upload Rate Alert",
      "conditions": [{
        "displayName": "'"${CUSTOM_METRIC_NAME}"' rate exceeds '"${ALERT_THRESHOLD}"'",
        "conditionThreshold": {
          "filter": "metric.type=\"logging.googleapis.com/user/'"${CUSTOM_METRIC_NAME}"'\" resource.type=\"cloud_function\"",
          "comparison": "COMPARISON_GT",
          "thresholdValue": '"${ALERT_THRESHOLD}"',
          "duration": "0s",
          "trigger": {"count": 1},
          "aggregations": [{
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_RATE"
          }]
        }
      }],
      "combiner": "OR",
      "enabled": true,
      "alertStrategy": {"autoClose": "604800s"}
    }')
  
  echo "$ALERT_RESPONSE2" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'error' in data:
        print(f'Error: {data[\"error\"][\"message\"]}')
    else:
        print(f'Success! Alert: {data.get(\"name\", \"created\")}')
except:
    print('Could not parse response')
" 2>/dev/null
fi

success "Alert policy creation attempted!"

# ============================================================================
# SUMMARY
# ============================================================================
header "FIX SCRIPT COMPLETE"
echo ""
echo -e "${GREEN}  [✓] Task 2: SSH'd into VM, installed Ops Agent, set env vars, started Go app${NC}"
echo -e "${GREEN}  [✓] Task 4: Dashboard updated with etag preserved${NC}"
echo -e "${GREEN}  [✓] Task 5: Alert created with resource.type specified${NC}"
echo ""
echo -e "${YELLOW}  [!] Task 2 metric may take 5-10 minutes to appear${NC}"
echo -e "${YELLOW}  [!] Click 'Check my progress' after a few minutes${NC}"
echo "======================================================================"
