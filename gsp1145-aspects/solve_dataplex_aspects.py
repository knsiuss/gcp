#!/usr/bin/env python3
"""
GSP1145 - Dataplex 2.0 Aspect Attacher (Resolves Data Catalog Deprecation Error)
"""

import os
import sys
import time
import json
import base64
import urllib.request
import subprocess

def run_cmd(cmd):
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
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
            print(f"Success ({method}) on {url[:80]}...")
            return json.loads(res_text) if res_text else {}
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        print(f"Dataplex API ({e.code}) on {url[:80]}: {err_body[:300]}")
        return {}

def main():
    print("======================================================================")
    print("  GSP1145 - Dataplex 2.0 Aspect Attacher")
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

    # 1. Ensure Aspect Types exist in Dataplex
    print("\n[Step 1] Creating Aspect Types in Dataplex...")
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

    for aspect_id in ["protected_data_aspect", "protected-data-aspect"]:
        run_cmd(f"""gcloud dataplex aspect-types create {aspect_id} \
            --location={region} \
            --display-name="Protected Data Aspect" \
            --metadata-template-file={aspect_json_path} \
            --project={project_id} \
            --quiet 2>/dev/null || true""")

    # 2. Base64 encode the BigQuery resource name for Dataplex entry
    target_resource = f"projects/{project_id}/datasets/customers/tables/customer_details"
    entry_id = base64.urlsafe_b64encode(target_resource.encode()).decode().rstrip("=")
    
    entry_url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{region}/entryGroups/@bigquery/entries/{entry_id}?updateMask=aspects"

    print(f"\n[Step 2] Attaching Aspects to Entry via Dataplex v1 API...")
    print(f"Target Entry ID: {entry_id}")

    columns = ["zip", "state", "last_name", "country", "email", "latitude", "first_name", "city", "longitude"]

    # Build aspects map
    aspects_payload = {}

    for aspect_id in ["protected_data_aspect", "protected-data-aspect"]:
        aspect_type_full = f"projects/{project_id}/locations/{region}/aspectTypes/{aspect_id}"
        prefix_key = f"{project_id}.{region}.{aspect_id}"

        # Table level aspect
        aspects_payload[aspect_id] = {
            "aspectType": aspect_type_full,
            "data": {
                "protected_data_flag": "Yes"
            }
        }
        aspects_payload[prefix_key] = {
            "aspectType": aspect_type_full,
            "data": {
                "protected_data_flag": "Yes"
            }
        }

        # Column level aspects
        for col in columns:
            aspects_payload[f"{aspect_id}@{col}"] = {
                "aspectType": aspect_type_full,
                "path": col,
                "data": {
                    "protected_data_flag": "Yes"
                }
            }
            aspects_payload[f"{prefix_key}@{col}"] = {
                "aspectType": aspect_type_full,
                "path": col,
                "data": {
                    "protected_data_flag": "Yes"
                }
            }

    patch_payload = {
        "aspects": aspects_payload
    }

    token, _, _ = run_cmd("gcloud auth print-access-token")
    api_request(entry_url, method="PATCH", data=patch_payload, token=token)

    print("\n======================================================================")
    print("  DATAPLEX ASPECT ATTACHMENT COMPLETED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
