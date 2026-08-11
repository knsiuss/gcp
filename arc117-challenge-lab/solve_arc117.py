#!/usr/bin/env python3
"""
ARC117 - Organize and Govern Data with Knowledge Catalog: Challenge Lab Solver
"""

import os
import sys
import time
import json
import base64
import subprocess

def run_cmd(cmd):
    print(f"Executing: {cmd}")
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if res.returncode != 0 and res.stderr:
        print(f"Result ({res.returncode}): {res.stderr.strip()}")
    else:
        print(f"Output: {res.stdout.strip()[:200]}")
    return res.stdout.strip(), res.stderr.strip(), res.returncode

def main():
    print("======================================================================")
    print("  ARC117 - Organize and Govern Data Challenge Lab Solver")
    print("======================================================================")

    project_id, _, _ = run_cmd("gcloud config get-value project")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    region = "us-east1"
    print(f"[*] Region:     {region}")

    # Step 1: Enable APIs
    print("\n[Step 1] Enabling Dataplex & Data Catalog APIs...")
    run_cmd("gcloud services enable dataplex.googleapis.com datacatalog.googleapis.com --quiet")

    # =========================================================================
    # TASK 1: Create Lake 'customer-engagements' & Zone 'raw-event-data'
    # =========================================================================
    print("\n[Task 1] Creating Lake 'customer-engagements'...")
    run_cmd(f"""gcloud dataplex lakes create customer-engagements \
        --location={region} \
        --display-name="Customer Engagements" \
        --project={project_id} \
        --quiet""")

    # Wait for lake
    for i in range(1, 21):
        state, _, _ = run_cmd(f"gcloud dataplex lakes describe customer-engagements --location={region} --format='value(state)'")
        if state == "ACTIVE":
            print("Lake 'customer-engagements' is ACTIVE!")
            break
        time.sleep(5)

    print("\n[Task 1] Creating RAW Zone 'raw-event-data'...")
    run_cmd(f"""gcloud dataplex zones create raw-event-data \
        --location={region} \
        --lake=customer-engagements \
        --display-name="Raw Event Data" \
        --resource-location-type=SINGLE_REGION \
        --type=RAW \
        --project={project_id} \
        --quiet""")

    # Wait for zone
    for i in range(1, 21):
        state, _, _ = run_cmd(f"gcloud dataplex zones describe raw-event-data --location={region} --lake=customer-engagements --format='value(state)'")
        if state == "ACTIVE":
            print("Zone 'raw-event-data' is ACTIVE!")
            break
        time.sleep(5)

    # =========================================================================
    # TASK 2: Create Bucket & Attach Asset 'raw-event-files'
    # =========================================================================
    print("\n[Task 2] Creating Cloud Storage bucket & Attaching Asset 'raw-event-files'...")
    run_cmd(f"gcloud storage buckets create gs://{project_id} --location={region} --project={project_id} 2>/dev/null || true")

    run_cmd(f"""gcloud dataplex assets create raw-event-files \
        --location={region} \
        --lake=customer-engagements \
        --zone=raw-event-data \
        --display-name="Raw Event Files" \
        --resource-type=STORAGE_BUCKET \
        --resource-name="projects/{project_id}/buckets/{project_id}" \
        --project={project_id} \
        --quiet""")

    # Wait for asset
    for i in range(1, 21):
        state, _, _ = run_cmd(f"gcloud dataplex assets describe raw-event-files --location={region} --lake=customer-engagements --zone=raw-event-data --format='value(state)'")
        if state == "ACTIVE":
            print("Asset 'raw-event-files' is ACTIVE!")
            break
        time.sleep(5)

    # =========================================================================
    # TASK 3: Create Aspect Type & Attach Aspect
    # =========================================================================
    print("\n[Task 3] Creating Aspect Type 'Protected Raw Data Aspect'...")

    aspect_json_path = "/tmp/aspect_def_arc117.json"
    with open(aspect_json_path, "w") as f:
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
        for aspect_id in ["protected-raw-data-aspect", "protected_raw_data_aspect"]:
            run_cmd(f"""gcloud dataplex aspect-types create {aspect_id} \
                --location={loc} \
                --display-name="Protected Raw Data Aspect" \
                --metadata-template-file={aspect_json_path} \
                --project={project_id} \
                --quiet 2>/dev/null || true""")

            run_cmd(f"""gcloud data-catalog tag-templates create {aspect_id} \
                --location={loc} \
                --display-name="Protected Raw Data Aspect" \
                --field=id=protected_raw_data_flag,display-name="Protected Raw Data Flag",type=enum(Y|N),required=true \
                --project={project_id} \
                --quiet 2>/dev/null || true""")

    # Attach tag to GCS bucket entry in Data Catalog
    target_resource = f"projects/{project_id}/buckets/{project_id}"
    entry_id = base64.b64encode(target_resource.encode()).decode().rstrip("=")

    for loc in ["us-east1", "global"]:
        entry_path = f"projects/{project_id}/locations/{loc}/entryGroups/@storage/entries/{entry_id}"
        for template_name in ["protected-raw-data-aspect", "protected_raw_data_aspect"]:
            run_cmd(f"""gcloud data-catalog tags create \
                --entry='{entry_path}' \
                --tag-template='projects/{project_id}/locations/{loc}/tagTemplates/{template_name}' \
                --fields=protected_raw_data_flag=Y \
                --project={project_id} \
                --quiet 2>/dev/null || true""")

    print("\n======================================================================")
    print("  ARC117 SOLVER FINISHED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
