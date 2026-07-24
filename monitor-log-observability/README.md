# GSP338 - Monitor and Log with Google Cloud Observability: Challenge Lab

## Quick Start

### 1. Open Cloud Shell and clone the repo:
```bash
git clone https://github.com/knsiuss/gcp.git ~/gcp-labs && cd ~/gcp-labs/monitor-log-observability
```

### 2. Run the script:
```bash
chmod +x solve_gsp338.sh && ./solve_gsp338.sh
```

### 3. With custom parameters (if values differ):
```bash
chmod +x solve_gsp338.sh && ./solve_gsp338.sh <CUSTOM_METRIC_NAME> <ALERT_THRESHOLD>
```

Example:
```bash
./solve_gsp338.sh big_video_upload_rate 4
```

## What the script does:

| Task | Action |
|------|--------|
| Task 1 | Enables Cloud Monitoring & Logging APIs |
| Task 2 | Fixes video-queue-monitor VM startup script (adds Ops Agent + env vars), restarts VM |
| Task 3 | Creates log-based metric with filter for 4K/8K video uploads |
| Task 4 | Adds two charts to Media_Dashboard (queue size + upload rate) |
| Task 5 | Creates alerting policy with configurable threshold |

## Notes:
- Task 2's custom metric may take **5-10 minutes** to appear in Metrics Explorer
- Task 4 charts may take **5-10 minutes** to show data
- Default metric name: `big_video_upload_rate`
- Default alert threshold: `4`
