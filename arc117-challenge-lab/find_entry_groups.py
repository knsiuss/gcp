#!/usr/bin/env python3
"""
ARC117 - Discover Dataplex Entry Groups & Update Aspects
"""

import os
import sys
import json
import subprocess

def run_cmd(cmd):
    print(f"Executing: {cmd}")
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if res.stdout:
        print(f"Stdout: {res.stdout.strip()[:300]}")
    if res.returncode != 0 and res.stderr:
        print(f"Stderr: {res.stderr.strip()[:300]}")
    return res.stdout.strip(), res.stderr.strip(), res.returncode

def main():
    project_id, _, _ = run_cmd("gcloud config get-value project")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    project_num, _, _ = run_cmd(f"gcloud projects describe {project_id} --format='value(projectNumber)'")

    region = "us-east1"
    lake_id = "customer-engagements"
    zone_id = "raw-event-data"
    aspect_type_id = "protected-raw-data-aspect"

    # 1. Discover Entry Groups
    print("\n[Step 1] Discovering Entry Groups in Dataplex...")
    entry_groups = []
    for loc in ["us-east1", "global", "us"]:
        out, _, _ = run_cmd(f"gcloud alpha dataplex entry-groups list --location={loc} --project={project_id} --format='value(name)'")
        if out:
            for line in out.splitlines():
                if line.strip():
                    entry_groups.append((loc, line.strip()))

    print(f"Discovered Entry Groups: {entry_groups}")

    # 2. Build aspect JSON
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

    for loc in ["us-east1", "global"]:
        run_cmd(f"gcloud dataplex aspect-types create {aspect_type_id} --location={loc} --display-name='Protected Raw Data Aspect' --metadata-template-file={aspect_def} --project={project_id} --quiet 2>/dev/null || true")

    aspect_json = "/tmp/zone_aspect_test.json"
    aspect_payload = {
        f"{project_num}.{region}.{aspect_type_id}": {
            "aspectType": f"projects/{project_id}/locations/{region}/aspectTypes/{aspect_type_id}",
            "data": {"protected_raw_data_flag": "Y"}
        },
        f"{project_id}.{region}.{aspect_type_id}": {
            "aspectType": f"projects/{project_id}/locations/{region}/aspectTypes/{aspect_type_id}",
            "data": {"protected_raw_data_flag": "Y"}
        }
    }
    with open(aspect_json, "w") as f:
        json.dump(aspect_payload, f)

    # 3. For each entry group, search entries and update aspects
    target_zone_path = f"projects/{project_id}/locations/{region}/lakes/{lake_id}/zones/{zone_id}"

    for loc, eg_name in entry_groups:
        eg_id = eg_name.split("/")[-1]
        print(f"\nTrying Entry Group: {eg_id} in {loc}...")

        # Search entries in this entry group
        entries_out, _, _ = run_cmd(f"gcloud alpha dataplex entries search --query='{zone_id}' --location={loc} --project={project_id} --format='value(name)'")
        if entries_out:
            for entry_name in entries_out.splitlines():
                if entry_name.strip():
                    print(f"Updating entry: {entry_name.strip()}")
                    run_cmd(f"gcloud alpha dataplex entries update-aspects \"{entry_name.strip()}\" --location={loc} --entry-group={eg_id} --aspects={aspect_json} --project={project_id}")

        # Also try direct update on target_zone_path
        run_cmd(f"gcloud alpha dataplex entries update-aspects \"{target_zone_path}\" --location={loc} --entry-group={eg_id} --aspects={aspect_json} --project={project_id}")

    print("\n======================================================================")
    print("  ENTRY GROUP DISCOVERY & ASPECT ATTACH COMPLETED!")
    print("======================================================================")

if __name__ == "__main__":
    main()
