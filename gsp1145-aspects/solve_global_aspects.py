#!/usr/bin/env python3
"""
GSP1145 - Global Aspect Type & Entry Attacher for Dataplex 2.0
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
            print(f"Success ({method}) on {url[:90]}")
            return json.loads(res_text) if res_text else {}
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        print(f"Dataplex API ({e.code}) on {url[:90]}: {err_body[:300]}")
        return {}

def main():
    print("======================================================================")
    print("  GSP1145 - Global Aspect Type & Entry Attacher")
    print("======================================================================")

    project_id, _, _ = run_cmd("gcloud config get-value project")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    # Detect dataset 'customers' region
    bq_out, _, _ = run_cmd(f"bq show --format=json {project_id}:customers")
    region = "us-west1"
    if bq_out:
        try:
            region = json.loads(bq_out).get("location", "us-central1").lower()
        except Exception:
            pass
    print(f"[*] Region:     {region}")

    # 1. Create Aspect Types in BOTH 'global' and dataset region
    print("\n[Step 1] Creating Aspect Types in 'global' and regional locations...")
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

    for loc in ["global", region]:
        for aspect_id in ["protected_data_aspect", "protected-data-aspect"]:
            run_cmd(f"""gcloud dataplex aspect-types create {aspect_id} \
                --location={loc} \
                --display-name="Protected Data Aspect" \
                --metadata-template-file={aspect_json_path} \
                --project={project_id} \
                --quiet 2>/dev/null || true""")

    # 2. Base64 encode the BigQuery resource name for Dataplex entry
    target_resource = f"projects/{project_id}/datasets/customers/tables/customer_details"
    b64_std = base64.b64encode(target_resource.encode()).decode().rstrip("=")
    b64_url = base64.urlsafe_b64encode(target_resource.encode()).decode().rstrip("=")

    columns = ["zip", "state", "last_name", "country", "email", "latitude", "first_name", "city", "longitude"]

    print("\n[Step 2] Attaching Aspects to Entry via Dataplex v1 API...")

    for loc in ["global", region]:
        for entry_code in [b64_std, b64_url]:
            entry_url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{loc}/entryGroups/@bigquery/entries/{entry_code}?updateMask=aspects"
            
            for aspect_id in ["protected_data_aspect", "protected-data-aspect"]:
                aspect_type_full = f"projects/{project_id}/locations/{loc}/aspectTypes/{aspect_id}"
                full_key = f"{project_id}.{loc}.{aspect_id}"

                aspects_payload = {
                    full_key: {
                        "aspectType": aspect_type_full,
                        "data": {
                            "protected_data_flag": "Yes"
                        }
                    }
                }

                for col in columns:
                    aspects_payload[f"{full_key}@{col}"] = {
                        "aspectType": aspect_type_full,
                        "path": col,
                        "data": {
                            "protected_data_flag": "Yes"
                        }
                    }

                patch_payload = {"aspects": aspects_payload}
                token, _, _ = run_cmd("gcloud auth print-access-token")
                api_request(entry_url, method="PATCH", data=patch_payload, token=token)

    print("\n======================================================================")
    print("  GLOBAL DATAPLEX ASPECT ATTACHMENT FINISHED!")
    print("======================================================================")

if __name__ == "__main__":
    main()
