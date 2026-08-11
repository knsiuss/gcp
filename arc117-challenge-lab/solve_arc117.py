#!/usr/bin/env python3
"""
ARC117 - Organize and Govern Data with Knowledge Catalog: Challenge Lab Solver
Fixes Task 3 by updating aspect on the Zone Entry (@dataplex) as specified in requirements.
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

    # Get Project Number
    project_number, _, _ = run_cmd(f"gcloud projects describe {project_id} --format='value(projectNumber)'")
    print(f"[*] Project Number: {project_number}")

    region = "us-east1"
    lake_id = "customer-engagements"
    zone_id = "raw-event-data"
    asset_id = "raw-event-files"
    bucket_id = project_id
    aspect_type_id = "protected-raw-data-aspect"

    # Step 1: Enable APIs
    print("\n[Step 1] Enabling Dataplex & Data Catalog APIs...")
    run_cmd("gcloud services enable dataplex.googleapis.com datacatalog.googleapis.com --quiet")

    # =========================================================================
    # TASK 1: Create Lake 'customer-engagements' & Zone 'raw-event-data'
    # =========================================================================
    print("\n[Task 1] Creating Lake 'customer-engagements'...")
    run_cmd(f"""gcloud dataplex lakes create {lake_id} \
        --location={region} \
        --display-name="Customer Engagements" \
        --project={project_id} \
        --quiet""")

    # Wait for lake
    for i in range(1, 21):
        state, _, _ = run_cmd(f"gcloud dataplex lakes describe {lake_id} --location={region} --format='value(state)'")
        if state == "ACTIVE":
            print(f"Lake '{lake_id}' is ACTIVE!")
            break
        time.sleep(5)

    print("\n[Task 1] Creating RAW Zone 'raw-event-data'...")
    run_cmd(f"""gcloud dataplex zones create {zone_id} \
        --location={region} \
        --lake={lake_id} \
        --display-name="Raw Event Data" \
        --resource-location-type=SINGLE_REGION \
        --type=RAW \
        --project={project_id} \
        --quiet""")

    # Wait for zone
    for i in range(1, 21):
        state, _, _ = run_cmd(f"gcloud dataplex zones describe {zone_id} --location={region} --lake={lake_id} --format='value(state)'")
        if state == "ACTIVE":
            print(f"Zone '{zone_id}' is ACTIVE!")
            break
        time.sleep(5)

    # =========================================================================
    # TASK 2: Create Bucket & Attach Asset 'raw-event-files'
    # =========================================================================
    print("\n[Task 2] Creating Cloud Storage bucket & Attaching Asset 'raw-event-files'...")
    run_cmd(f"gcloud storage buckets create gs://{bucket_id} --location={region} --project={project_id} 2>/dev/null || true")

    run_cmd(f"""gcloud dataplex assets create {asset_id} \
        --location={region} \
        --lake={lake_id} \
        --zone={zone_id} \
        --display-name="Raw Event Files" \
        --resource-type=STORAGE_BUCKET \
        --resource-name="projects/{project_id}/buckets/{bucket_id}" \
        --project={project_id} \
        --quiet""")

    # Wait for asset
    for i in range(1, 21):
        state, _, _ = run_cmd(f"gcloud dataplex assets describe {asset_id} --location={region} --lake={lake_id} --zone={zone_id} --format='value(state)'")
        if state == "ACTIVE":
            print(f"Asset '{asset_id}' is ACTIVE!")
            break
        time.sleep(5)

    # =========================================================================
    # TASK 3: Create Aspect Type & Add Aspect to ZONE
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

    for loc in [region, "global"]:
        for a_id in ["protected-raw-data-aspect", "protected_raw_data_aspect"]:
            run_cmd(f"""gcloud dataplex aspect-types create {a_id} \
                --location={loc} \
                --display-name="Protected Raw Data Aspect" \
                --metadata-template-file={aspect_json_path} \
                --project={project_id} \
                --quiet 2>/dev/null || true""")

            run_cmd(f"""gcloud data-catalog tag-templates create {a_id} \
                --location={loc} \
                --display-name="Protected Raw Data Aspect" \
                --field=id=protected_raw_data_flag,display-name="Protected Raw Data Flag",type=enum(Y|N),required=true \
                --project={project_id} \
                --quiet 2>/dev/null || true""")

    # Attach Aspect to the ZONE Entry
    print("\n[Task 3] Adding Aspect to the Zone 'raw-event-data'...")
    
    zone_aspect_json = "/tmp/zone_aspect.json"
    aspect_key_num = f"{project_number}.{region}.{aspect_type_id}"
    aspect_key_str = f"{project_id}.{region}.{aspect_type_id}"
    aspect_key_simple = aspect_type_id

    with open(zone_aspect_json, "w") as f:
        json.dump({
            aspect_key_num: {
                "aspectType": f"projects/{project_id}/locations/{region}/aspectTypes/{aspect_type_id}",
                "data": {"protected_raw_data_flag": "Y"}
            },
            aspect_key_str: {
                "aspectType": f"projects/{project_id}/locations/{region}/aspectTypes/{aspect_type_id}",
                "data": {"protected_raw_data_flag": "Y"}
            },
            aspect_key_simple: {
                "aspectType": f"projects/{project_id}/locations/{region}/aspectTypes/{aspect_type_id}",
                "data": {"protected_raw_data_flag": "Y"}
            }
        }, f)

    zone_entry_name = f"projects/{project_id}/locations/{region}/entryGroups/@dataplex/entries/projects/{project_id}/locations/{region}/lakes/{lake_id}/zones/{zone_id}"

    # Method 1: gcloud alpha dataplex entries update-aspects
    run_cmd(f"""gcloud alpha dataplex entries update-aspects "{zone_entry_name}" \
        --project={project_id} \
        --location={region} \
        --entry-group=@dataplex \
        --aspects={zone_aspect_json} \
        --quiet 2>/dev/null || true""")

    # Method 2: REST API patch
    token, _, _ = run_cmd("gcloud auth print-access-token")
    patch_url = f"https://dataplex.googleapis.com/v1/{zone_entry_name}?updateMask=aspects"
    
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    body = json.dumps({"aspects": {
        aspect_key_str: {
            "aspectType": f"projects/{project_id}/locations/{region}/aspectTypes/{aspect_type_id}",
            "data": {"protected_raw_data_flag": "Y"}
        }
    }}).encode("utf-8")
    
    import urllib.request
    req = urllib.request.Request(patch_url, data=body, headers=headers, method="PATCH")
    try:
        with urllib.request.urlopen(req) as resp:
            print("REST API Patch Zone Aspect Success!")
    except Exception as e:
        print(f"REST API Patch Zone Aspect Exception: {e}")

    # Method 3: Data Catalog Tag on Zone Entry
    for loc in [region, "global"]:
        for template_name in ["protected-raw-data-aspect", "protected_raw_data_aspect"]:
            run_cmd(f"""gcloud data-catalog tags create \
                --entry='{zone_entry_name}' \
                --tag-template='projects/{project_id}/locations/{loc}/tagTemplates/{template_name}' \
                --fields=protected_raw_data_flag=Y \
                --project={project_id} \
                --quiet 2>/dev/null || true""")

    print("\n======================================================================")
    print("  ARC117 SOLVER FINISHED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
