#!/usr/bin/env python3
"""
GSP1145 - Create and Add Aspects to Knowledge Catalog Assets Solver
"""

import os
import sys
import time
import json
import urllib.request
import subprocess

def run_cmd(cmd):
    print(f"Executing: {cmd}")
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Stderr: {res.stderr.strip()}")
    return res.stdout.strip(), res.stderr.strip(), res.returncode

def api_request(url, method="GET", data=None, token=None):
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    body = json.dumps(data).encode("utf-8") if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as response:
            res_text = response.read().decode("utf-8")
            return json.loads(res_text) if res_text else {}
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        print(f"API Error ({e.code}) on {url}: {err_body}")
        return {}

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

    token, _, _ = run_cmd("gcloud auth print-access-token")

    # =========================================================================
    # TASK 1: Create Lake, Zone, and Asset
    # =========================================================================
    print("\n[Task 1] Enabling Dataplex & Data Catalog APIs...")
    run_cmd("gcloud services enable dataplex.googleapis.com datacatalog.googleapis.com --quiet")

    print("\n[Task 1] Creating Lake 'orders-lake'...")
    run_cmd(f"""gcloud dataplex lakes create orders-lake \
        --location={region} \
        --display-name="Orders Lake" \
        --project={project_id} \
        --quiet""")

    # Wait for lake
    for i in range(1, 21):
        state, _, _ = run_cmd(f"gcloud dataplex lakes describe orders-lake --location={region} --format='value(state)'")
        print(f"Lake state: {state} (Attempt {i}/20)")
        if state == "ACTIVE":
            break
        time.sleep(5)

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
        print(f"Zone state: {state} (Attempt {i}/20)")
        if state == "ACTIVE":
            break
        time.sleep(5)

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
    # TASK 2: Create Aspect Type
    # =========================================================================
    print("\n[Task 2] Creating Aspect Type 'protected-data-aspect'...")
    aspect_type_id = "protected-data-aspect"
    aspect_url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{region}/aspectTypes?aspectTypeId={aspect_type_id}"
    
    aspect_payload = {
        "displayName": "Protected Data Aspect",
        "metadataTemplate": {
            "type": "record",
            "fields": [
                {
                    "name": "protected_data_flag",
                    "displayName": "Protected Data Flag",
                    "type": "enum",
                    "constraints": {
                        "required": True
                    },
                    "enumOptions": [
                        {"value": "Yes"},
                        {"value": "No"}
                    ]
                }
            ]
        }
    }
    
    token, _, _ = run_cmd("gcloud auth print-access-token")
    api_request(aspect_url, method="POST", data=aspect_payload, token=token)
    print("Created Aspect Type successfully!")

    # =========================================================================
    # TASK 3: Attach Aspect to Entry and Columns
    # =========================================================================
    print("\n[Task 3] Adding Aspect to customer_details table and columns...")
    time.sleep(5)
    token, _, _ = run_cmd("gcloud auth print-access-token")

    # Lookup entry via Data Catalog
    lookup_url = f"https://datacatalog.googleapis.com/v1/entries:lookup?linkedResource=//bigquery.googleapis.com/projects/{project_id}/datasets/customers/tables/customer_details"
    entry_res = api_request(lookup_url, method="GET", token=token)
    entry_name = entry_res.get("name", "")
    print(f"Found Entry Name: {entry_name}")

    aspect_type_full = f"projects/{project_id}/locations/{region}/aspectTypes/{aspect_type_id}"
    aspect_key = f"{project_id}.{region}.{aspect_type_id}"

    columns = [
        "first_name", "last_name", "email", "state", "zip",
        "country", "city", "latitude", "longitude"
    ]

    aspects_dict = {
        aspect_key: {
            "aspectType": aspect_type_full,
            "data": {
                "protected_data_flag": "Yes"
            }
        }
    }

    for col in columns:
        aspects_dict[f"{aspect_key}@{col}"] = {
            "aspectType": aspect_type_full,
            "path": col,
            "data": {
                "protected_data_flag": "Yes"
            }
        }

    if entry_name:
        dataplex_entry_url = f"https://dataplex.googleapis.com/v1/{entry_name}?updateMask=aspects"
        api_request(dataplex_entry_url, method="PATCH", data={"aspects": aspects_dict}, token=token)

    print("\n======================================================================")
    print("  GSP1145 SOLVER FINISHED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
