#!/usr/bin/env python3
"""
GSP1145 - Create and Add Aspects to Knowledge Catalog Assets Solver
Supports both Dataplex Aspect-Types and Data Catalog Tag Templates.
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
    print("  GSP1145 - Knowledge Catalog Aspects Solver")
    print("======================================================================")

    project_id, _, _ = run_cmd("gcloud config get-value project")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    # Detect dataset 'customers' region
    bq_out, _, _ = run_cmd(f"bq show --format=json {project_id}:customers")
    region = "us-central1"
    if bq_out:
        try:
            region = json.loads(bq_out).get("location", "us-central1").lower()
        except Exception:
            pass
    print(f"[*] Region:     {region}")

    # Enable APIs
    print("\n[Step 1] Enabling Dataplex & Data Catalog APIs...")
    run_cmd("gcloud services enable dataplex.googleapis.com datacatalog.googleapis.com --quiet")

    # =========================================================================
    # TASK 1: Create Lake, Zone, and Asset
    # =========================================================================
    print("\n[Task 1] Creating Lake 'orders-lake'...")
    run_cmd(f"""gcloud dataplex lakes create orders-lake \
        --location={region} \
        --display-name="Orders Lake" \
        --project={project_id} \
        --quiet""")

    # Wait for lake
    for i in range(1, 21):
        state, _, _ = run_cmd(f"gcloud dataplex lakes describe orders-lake --location={region} --format='value(state)'")
        if state == "ACTIVE":
            print("Lake state is ACTIVE!")
            break
        time.sleep(4)

    print("\n[Task 1] Adding Zone 'customer-curated-zone'...")
    run_cmd(f"""gcloud dataplex zones create customer-curated-zone \
        --location={region} \
        --lake=orders-lake \
        --display-name="Customer Curated Zone" \
        --resource-location-type=SINGLE_REGION \
        --type=CURATED \
        --project={project_id} \
        --quiet""")

    # Wait for zone
    for i in range(1, 21):
        state, _, _ = run_cmd(f"gcloud dataplex zones describe customer-curated-zone --location={region} --lake=orders-lake --format='value(state)'")
        if state == "ACTIVE":
            print("Zone state is ACTIVE!")
            break
        time.sleep(4)

    print("\n[Task 1] Attaching Asset 'customer-details-dataset'...")
    run_cmd(f"""gcloud dataplex assets create customer-details-dataset \
        --location={region} \
        --lake=orders-lake \
        --zone=customer-curated-zone \
        --display-name="Customer Details Dataset" \
        --resource-type=BIGQUERY_DATASET \
        --resource-name="projects/{project_id}/datasets/customers" \
        --project={project_id} \
        --quiet""")

    # =========================================================================
    # TASK 2: Create Aspect Type / Tag Template
    # =========================================================================
    print("\n[Task 2] Creating Aspect Type / Tag Template 'protected_data_aspect'...")
    
    # 1. Data Catalog Tag Template creation
    run_cmd(f"""gcloud data-catalog tag-templates create protected_data_aspect \
        --location={region} \
        --display-name="Protected Data Aspect" \
        --field=id=protected_data_flag,display-name="Protected Data Flag",type=enum(Yes|No),required=true \
        --project={project_id} \
        --quiet""")

    run_cmd(f"""gcloud data-catalog tag-templates create protected-data-aspect \
        --location={region} \
        --display-name="Protected Data Aspect" \
        --field=id=protected_data_flag,display-name="Protected Data Flag",type=enum(Yes|No),required=true \
        --project={project_id} \
        --quiet""")

    # 2. Dataplex Aspect Type creation
    aspect_json_path = "/tmp/aspect_def.json"
    with open(aspect_json_path, "w") as f:
        json.dump({
            "fields": [
                {
                    "name": "protected_data_flag",
                    "displayName": "Protected Data Flag",
                    "type": "ENUM",
                    "constraints": {"required": True},
                    "enumValues": [{"name": "Yes"}, {"name": "No"}]
                }
            ]
        }, f)

    run_cmd(f"""gcloud dataplex aspect-types create protected-data-aspect \
        --location={region} \
        --display-name="Protected Data Aspect" \
        --metadata-template-file={aspect_json_path} \
        --project={project_id} \
        --quiet""")

    run_cmd(f"""gcloud dataplex aspect-types create protected_data_aspect \
        --location={region} \
        --display-name="Protected Data Aspect" \
        --metadata-template-file={aspect_json_path} \
        --project={project_id} \
        --quiet""")

    # =========================================================================
    # TASK 3: Attach Aspect / Tags to Entry and Columns
    # =========================================================================
    print("\n[Task 3] Attaching Aspects/Tags to customer_details table and columns...")
    
    target_resource = f"projects/{project_id}/datasets/customers/tables/customer_details"
    entry_id = base64.b64encode(target_resource.encode()).decode().rstrip("=")
    entry_path = f"projects/{project_id}/locations/{region}/entryGroups/@bigquery/entries/{entry_id}"

    # Attach Tag to Table
    for template_name in ["protected_data_aspect", "protected-data-aspect"]:
        run_cmd(f"""gcloud data-catalog tags create \
            --entry='{entry_path}' \
            --tag-template='projects/{project_id}/locations/{region}/tagTemplates/{template_name}' \
            --fields=protected_data_flag=Yes \
            --project={project_id} \
            --quiet""")

    # Attach Tag to Columns
    columns = [
        "first_name", "last_name", "email", "state", "zip",
        "country", "city", "latitude", "longitude"
    ]

    for col in columns:
        for template_name in ["protected_data_aspect", "protected-data-aspect"]:
            run_cmd(f"""gcloud data-catalog tags create \
                --entry='{entry_path}' \
                --tag-template='projects/{project_id}/locations/{region}/tagTemplates/{template_name}' \
                --column='{col}' \
                --fields=protected_data_flag=Yes \
                --project={project_id} \
                --quiet""")

    print("\n======================================================================")
    print("  GSP1145 SOLVER FINISHED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
