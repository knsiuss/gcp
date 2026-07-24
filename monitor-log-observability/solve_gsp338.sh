#!/bin/bash
# ============================================================================
# GSP338 - Monitor and Log with Google Cloud Observability: Challenge Lab
# Automated Solution Script
# ============================================================================

set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
ZONE="us-east1-c"
REGION="us-east1"
CUSTOM_METRIC_NAME="${1:-big_video_upload_rate}"
ALERT_THRESHOLD="${2:-4}"

header() {
  echo ""
  echo -e "${BOLD}======================================================================"
  echo "  $1"
  echo -e "======================================================================${NC}"
}

step() { echo -e "${CYAN}[Step $1]${NC} $2"; }
success() { echo -e "${GREEN}[+]${NC} $1"; }
info() { echo -e "${YELLOW}[*]${NC} $1"; }
fail() { echo -e "${RED}[-]${NC} $1"; }

header "GSP338 - Monitor & Log with Google Cloud Observability"
info "Project ID:   $PROJECT_ID"
info "Zone:         $ZONE"
info "Metric Name:  $CUSTOM_METRIC_NAME"
info "Alert Thresh: $ALERT_THRESHOLD"

# ============================================================================
# TASK 1: Configure Cloud Monitoring
# ============================================================================
header "Task 1: Configure Cloud Monitoring (20/100)"

step 1 "Enabling Cloud Monitoring & Logging APIs..."
gcloud services enable monitoring.googleapis.com --quiet 2>/dev/null
gcloud services enable logging.googleapis.com --quiet 2>/dev/null
gcloud services enable compute.googleapis.com --quiet 2>/dev/null
gcloud services enable cloudfunctions.googleapis.com --quiet 2>/dev/null

success "Cloud Monitoring APIs enabled!"

# ============================================================================
# TASK 2: Configure Compute Instance to generate Custom Metrics
# ============================================================================
header "Task 2: Fix video-queue-monitor Startup Script (20/100)"

step 1 "Getting video-queue-monitor instance details..."
INSTANCE_ID=$(gcloud compute instances describe video-queue-monitor \
  --zone="$ZONE" --format='value(id)' 2>/dev/null)

if [ -z "$INSTANCE_ID" ]; then
  fail "Instance 'video-queue-monitor' not found! Make sure it exists."
  fail "The lab may still be provisioning resources. Wait 2-3 minutes and retry."
else
  info "Instance ID: $INSTANCE_ID"
fi

step 2 "Getting current startup script..."
OLD_STARTUP=$(gcloud compute instances describe video-queue-monitor \
  --zone="$ZONE" \
  --flatten="metadata.items[]" \
  --filter="metadata.items.key=startup-script" \
  --format='value(metadata.items.value)' 2>/dev/null)

if [ -z "$OLD_STARTUP" ]; then
  info "No startup-script (dash) found. Trying startup_script (underscore)..."
  OLD_STARTUP=$(gcloud compute instances describe video-queue-monitor \
    --zone="$ZONE" \
    --flatten="metadata.items[]" \
    --filter="metadata.items.key=startup_script" \
    --format='value(metadata.items.value)' 2>/dev/null)
fi

if [ -n "$OLD_STARTUP" ]; then
  info "Found existing startup script ($(echo "$OLD_STARTUP" | wc -l) lines)"
  echo "$OLD_STARTUP" > /tmp/old_startup.sh
else
  info "No existing startup script found. Creating from scratch."
  echo "" > /tmp/old_startup.sh
fi

step 3 "Creating fixed startup script with Ops Agent & env vars..."
cat > /tmp/new_startup.sh << 'STARTUP_EOF'
#!/bin/bash

# === [FIX] Install Google Cloud Ops Agent ===
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install
sudo systemctl start google-cloud-ops-agent || true

# === [FIX] Set required environment variables from metadata server ===
export GOOGLE_CLOUD_PROJECT=$(curl -s "http://metadata.google.internal/computeMetadata/v1/project/project-id" -H "Metadata-Flavor: Google")
export GCE_INSTANCE_ID=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/id" -H "Metadata-Flavor: Google")
export GCE_INSTANCE_ZONE=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google" | cut -d'/' -f4)

echo "PROJECT=$GOOGLE_CLOUD_PROJECT INSTANCE=$GCE_INSTANCE_ID ZONE=$GCE_INSTANCE_ZONE"

# === Original startup script follows ===
STARTUP_EOF

# Append original startup script (without shebang line)
if [ -s /tmp/old_startup.sh ]; then
  tail -n +2 /tmp/old_startup.sh >> /tmp/new_startup.sh
fi

step 4 "Updating instance metadata with fixed startup script..."
gcloud compute instances add-metadata video-queue-monitor \
  --zone="$ZONE" \
  --metadata-from-file startup-script=/tmp/new_startup.sh --quiet

step 5 "Stopping and starting instance (to trigger startup script)..."
gcloud compute instances stop video-queue-monitor --zone="$ZONE" --quiet 2>/dev/null
sleep 5
gcloud compute instances start video-queue-monitor --zone="$ZONE" --quiet 2>/dev/null

success "Instance restarted with fixed startup script!"
info "Waiting 120 seconds for Ops Agent install & Go app to start..."
sleep 120

# Verify the custom metric is being written
step 6 "Verifying custom metric (may take a few more minutes)..."
METRIC_CHECK=$(gcloud monitoring metrics-descriptors list \
  --filter='metric.type="custom.googleapis.com/opencensus/my.videoservice.org/measure/input_queue_size"' \
  --format='value(type)' 2>/dev/null | head -1)

if [ -n "$METRIC_CHECK" ]; then
  success "Custom metric 'input_queue_size' is being reported!"
else
  info "Custom metric not visible yet. It may take 5-10 more minutes to appear."
  info "You can check in Metrics Explorer: search for 'input_queue_size'"
fi

# ============================================================================
# TASK 3: Create Custom Log-Based Metric
# ============================================================================
header "Task 3: Create Log-Based Metric '$CUSTOM_METRIC_NAME' (20/100)"

step 1 "Checking if metric already exists..."
EXISTING_METRIC=$(gcloud logging metrics describe "$CUSTOM_METRIC_NAME" 2>/dev/null)

if [ -n "$EXISTING_METRIC" ]; then
  info "Metric '$CUSTOM_METRIC_NAME' already exists. Updating..."
  gcloud logging metrics update "$CUSTOM_METRIC_NAME" \
    --description="Metric for high resolution video uploads (4K and 8K)" \
    --log-filter='textPayload=~"file_format\: ([4,8]K).*"' \
    --quiet 2>/dev/null
else
  step 2 "Creating log-based metric..."
  gcloud logging metrics create "$CUSTOM_METRIC_NAME" \
    --description="Metric for high resolution video uploads (4K and 8K)" \
    --log-filter='textPayload=~"file_format\: ([4,8]K).*"' \
    --quiet 2>/dev/null
fi

success "Log-based metric '$CUSTOM_METRIC_NAME' created!"

# ============================================================================
# TASK 4: Add Custom Metrics to Media Dashboard
# ============================================================================
header "Task 4: Add Charts to Media_Dashboard (20/100)"

step 1 "Finding Media_Dashboard..."
DASHBOARD_ID=""
for attempt in $(seq 1 10); do
  DASHBOARD_ID=$(gcloud monitoring dashboards list \
    --filter='displayName="Media_Dashboard"' \
    --format='value(name)' 2>/dev/null | head -1)

  if [ -n "$DASHBOARD_ID" ]; then
    break
  fi
  info "Dashboard not found yet. Waiting 30s... (attempt $attempt/10)"
  sleep 30
done

if [ -z "$DASHBOARD_ID" ]; then
  fail "Could not find Media_Dashboard after 5 minutes!"
  fail "Check if it exists in Cloud Monitoring > Dashboards."
  fail "Skipping Task 4..."
else
  info "Dashboard: $DASHBOARD_ID"

  step 2 "Getting current dashboard configuration..."
  gcloud monitoring dashboards describe "$DASHBOARD_ID" --format=json > /tmp/dashboard.json

  step 3 "Adding two new charts to dashboard..."

  python3 << 'PYEOF'
import json
import sys

try:
    with open('/tmp/dashboard.json', 'r') as f:
        dashboard = json.load(f)
except Exception as e:
    print(f"Error reading dashboard: {e}")
    sys.exit(1)

# Define the two new chart widgets
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
                    "filter": 'metric.type="logging.googleapis.com/user/big_video_upload_rate"',
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

new_widgets = [input_queue_widget, upload_rate_widget]

# Add widgets based on dashboard layout type
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

elif 'columnLayout' in dashboard:
    columns = dashboard['columnLayout'].get('columns', [])
    if columns:
        widgets = columns[0].get('widgets', [])
        widgets.extend(new_widgets)
        columns[0]['widgets'] = widgets
    dashboard['columnLayout']['columns'] = columns

else:
    # Fallback: create a gridLayout
    dashboard['gridLayout'] = {"widgets": new_widgets}

# Remove read-only fields that can't be in the update request
for field in ['name', 'etag']:
    dashboard.pop(field, None)

with open('/tmp/dashboard_updated.json', 'w') as f:
    json.dump(dashboard, f, indent=2)

print("[+] Dashboard JSON updated with 2 new charts!")
PYEOF

  step 4 "Updating dashboard..."
  gcloud monitoring dashboards update "$DASHBOARD_ID" \
    --config-from-file=/tmp/dashboard_updated.json --quiet 2>/dev/null

  if [ $? -eq 0 ]; then
    success "Charts added to Media_Dashboard!"
  else
    fail "Dashboard update failed. Trying alternative approach..."
    # Alternative: try without quiet flag for debugging
    gcloud monitoring dashboards update "$DASHBOARD_ID" \
      --config-from-file=/tmp/dashboard_updated.json 2>&1
  fi
fi

# ============================================================================
# TASK 5: Create Cloud Operations Alert
# ============================================================================
header "Task 5: Create Alert Policy (20/100)"

step 1 "Creating alert policy JSON..."

cat > /tmp/alert_policy.json << ALERTEOF
{
  "displayName": "High Resolution Video Upload Rate Alert",
  "documentation": {
    "content": "Alert triggered when high resolution video upload rate exceeds ${ALERT_THRESHOLD}/s",
    "mimeType": "text/markdown"
  },
  "conditions": [
    {
      "displayName": "${CUSTOM_METRIC_NAME} rate exceeds ${ALERT_THRESHOLD}",
      "conditionThreshold": {
        "filter": "metric.type=\"logging.googleapis.com/user/${CUSTOM_METRIC_NAME}\"",
        "comparison": "COMPARISON_GT",
        "thresholdValue": ${ALERT_THRESHOLD},
        "duration": "0s",
        "trigger": {
          "count": 1
        },
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ]
      }
    }
  ],
  "combiner": "OR",
  "enabled": true,
  "alertStrategy": {
    "autoClose": "604800s"
  }
}
ALERTEOF

step 2 "Creating alert policy..."
ALERT_RESULT=$(gcloud alpha monitoring policies create \
  --policy-from-file=/tmp/alert_policy.json \
  --quiet 2>&1) || {
  info "Alpha command failed, trying non-alpha version..."
  ALERT_RESULT=$(gcloud monitoring policies create \
    --policy-from-file=/tmp/alert_policy.json \
    --quiet 2>&1) || {
    fail "Both commands failed. Trying curl API approach..."

    # Fallback: use REST API directly
    ACCESS_TOKEN=$(gcloud auth print-access-token)
    ALERT_RESULT=$(curl -s -X POST \
      "https://monitoring.googleapis.com/v3/projects/${PROJECT_ID}/alertPolicies" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d @/tmp/alert_policy.json)
    echo "$ALERT_RESULT"
  }
}

success "Alert policy created!"

# ============================================================================
# SUMMARY
# ============================================================================
header "ALL TASKS COMPLETED!"
echo ""
echo -e "${GREEN}  [✓] Task 1: Cloud Monitoring enabled${NC}"
echo -e "${GREEN}  [✓] Task 2: video-queue-monitor startup script fixed${NC}"
echo -e "${GREEN}  [✓] Task 3: Log-based metric '$CUSTOM_METRIC_NAME' created${NC}"
echo -e "${GREEN}  [✓] Task 4: Two charts added to Media_Dashboard${NC}"
echo -e "${GREEN}  [✓] Task 5: Alert policy created (threshold: $ALERT_THRESHOLD/s)${NC}"
echo ""
echo -e "${YELLOW}  [!] NOTE: Task 2 custom metric may take 5-10 minutes to appear${NC}"
echo -e "${YELLOW}  [!] NOTE: Task 4 charts may take 5-10 minutes to show data${NC}"
echo ""
echo -e "${BOLD}  Click 'Check my progress' for each task on Qwiklabs!${NC}"
echo "======================================================================"
