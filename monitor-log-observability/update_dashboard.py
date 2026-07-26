import json
import subprocess
import sys

def run_cmd(cmd):
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return res.stdout, res.stderr, res.returncode

def main():
    print("Finding Media_Dashboard...")
    stdout, _, _ = run_cmd("gcloud monitoring dashboards list --filter='displayName=\"Media_Dashboard\"' --format='value(name)'")
    dashboards = [line.strip() for line in stdout.splitlines() if line.strip()]

    if not dashboards:
        print("Media_Dashboard not found!")
        sys.exit(1)

    dashboard_name = dashboards[0]
    print(f"Dashboard Name: {dashboard_name}")

    # Describe dashboard
    stdout, stderr, ret = run_cmd(f"gcloud monitoring dashboards describe '{dashboard_name}' --format=json")
    if ret != 0:
        print(f"Error describing dashboard: {stderr}")
        sys.exit(1)

    dashboard = json.loads(stdout)
    etag = dashboard.get("etag", "")
    print(f"Current Dashboard Etag: {etag}")

    # Define the 2 widgets
    widget1 = {
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

    widget2 = {
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

    # Extract existing titles to avoid duplicate
    existing_titles = set()
    if "gridLayout" in dashboard:
        for w in dashboard["gridLayout"].get("widgets", []):
            existing_titles.add(w.get("title"))
    elif "mosaicLayout" in dashboard:
        for t in dashboard["mosaicLayout"].get("tiles", []):
            existing_titles.add(t.get("widget", {}).get("title"))

    new_widgets = []
    if "Video Input Queue Size" not in existing_titles:
        new_widgets.append(widget1)
    if "High Resolution Video Upload Rate" not in existing_titles:
        new_widgets.append(widget2)

    if not new_widgets:
        print("Both widgets already present in dashboard!")
    else:
        if "gridLayout" in dashboard:
            dashboard["gridLayout"].setdefault("widgets", []).extend(new_widgets)
        elif "mosaicLayout" in dashboard:
            tiles = dashboard["mosaicLayout"].setdefault("tiles", [])
            max_y = max([t.get("yPos", 0) + t.get("height", 0) for t in tiles], default=0)
            for i, w in enumerate(new_widgets):
                tiles.append({
                    "xPos": 0,
                    "yPos": max_y + (i * 16),
                    "width": 24,
                    "height": 16,
                    "widget": w
                })
        else:
            dashboard["gridLayout"] = {"columns": "2", "widgets": new_widgets}

    dashboard.pop("name", None)

    with open("/tmp/dashboard_final.json", "w") as f:
        json.dump(dashboard, f, indent=2)

    print("Updating Media_Dashboard...")
    stdout, stderr, ret = run_cmd(f"gcloud monitoring dashboards update '{dashboard_name}' --config-from-file=/tmp/dashboard_final.json --quiet")
    if ret == 0:
        print("Media_Dashboard updated successfully!")
    else:
        print(f"Failed to update dashboard: {stderr}")

if __name__ == "__main__":
    main()
