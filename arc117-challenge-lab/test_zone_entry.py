#!/usr/bin/env python3
"""
ARC117 - Test Zone Entry Description & Aspect Attachment via gcloud alpha dataplex
"""

import os
import sys
import json
import subprocess

def run_cmd(cmd):
    print(f"Executing: {cmd}")
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Stderr: {res.stderr.strip()[:300]}")
    else:
        print(f"Stdout: {res.stdout.strip()[:300]}")
    return res.stdout.strip(), res.stderr.strip(), res.returncode

def main():
    project_id, _, _ = run_cmd("gcloud config get-value project")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")

    project_num, _, _ = run_cmd(f"gcloud projects describe {project_id} --format='value(projectNumber)'")

    region = "us-east1"
    lake_id = "customer-engagements"
    zone_id = "raw-event-data"
    aspect_type_id = "protected-raw-data-aspect"

    # 1. Create Aspect Type
    aspect_def = "/tmp/aspect_def.json"
    with open(aspect_def, "w") as f:
        json.dump({
            "fields": [
                {
                    "name": "protected_raw_data_flag",
                    "displayName": "Protected Raw Data Flag",
                    "type": "ENUM",
                    "constraints": {"required": True},
                    "enumValues": [{"name": "Y"}, {"name": "N"}]
                }
            ]
        }, f)

    run_cmd(f"gcloud dataplex aspect-types create {aspect_type_id} --location={region} --display-name='Protected Raw Data Aspect' --metadata-template-file={aspect_def} --project={project_id} --quiet 2>/dev/null || true")

    # 2. Zone Entry Resource ID
    zone_entry_id = f"projects/{project_id}/locations/{region}/lakes/{lake_id}/zones/{zone_id}"

    # Check describe
    run_cmd(f"gcloud alpha dataplex entries describe \"{zone_entry_id}\" --location={region} --entry-group=@dataplex --project={project_id}")

    # 3. Build aspect json file matching project number and project id
    aspect_json = "/tmp/zone_aspect_test.json"
    aspect_payload = {
        f"{project_num}.{region}.{aspect_type_id}": {
            "aspectType": f"projects/{project_id}/locations/{region}/aspectTypes/{aspect_type_id}",
            "data": {
                "protected_raw_data_flag": "Y"
            }
        },
        f"{project_id}.{region}.{aspect_type_id}": {
            "aspectType": f"projects/{project_id}/locations/{region}/aspectTypes/{aspect_type_id}",
            "data": {
                "protected_raw_data_flag": "Y"
            }
        }
    }
    with open(aspect_json, "w") as f:
        json.dump(aspect_payload, f)

    # 4. Update aspects via gcloud alpha
    run_cmd(f"gcloud alpha dataplex entries update-aspects \"{zone_entry_id}\" --location={region} --entry-group=@dataplex --aspects={aspect_json} --project={project_id}")

    # Describe again to confirm aspects
    run_cmd(f"gcloud alpha dataplex entries describe \"{zone_entry_id}\" --location={region} --entry-group=@dataplex --project={project_id} --format='yaml(aspects)'")

if __name__ == "__main__":
    main()
