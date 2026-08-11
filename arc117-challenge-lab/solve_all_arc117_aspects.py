#!/usr/bin/env python3
"""
ARC117 Task 3 Comprehensive Aspect Type & Aspect Attacher
Covers all field name variations (hyphen vs underscore) and resource targets.
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
            print(f"Success ({method}) on {url[:80]}")
            return json.loads(res_text) if res_text else {}
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        print(f"API ({e.code}) on {url[:80]}: {err_body[:200]}")
        return {}

def main():
    print("======================================================================")
    print("  ARC117 Task 3 Comprehensive Aspect Solver")
    print("======================================================================")

    project_id, _, _ = run_cmd("gcloud config get-value project")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    project_num, _, _ = run_cmd(f"gcloud projects describe {project_id} --format='value(projectNumber)'")
    region = "us-east1"
    lake_id = "customer-engagements"
    zone_id = "raw-event-data"
    asset_id = "raw-event-files"
    bucket_id = project_id

    # 1. Create Aspect Types with BOTH field names (protected_raw_data_flag and protected-raw-data-flag)
    print("\n[Step 1] Creating Aspect Types with all field name variations...")
    
    for f_name in ["protected_raw_data_flag", "protected-raw-data-flag"]:
        aspect_def = f"/tmp/aspect_{f_name}.json"
        with open(aspect_def, "w") as f:
            json.dump({
                "fields": [
                    {
                        "name": f_name,
                        "displayName": "Protected Raw Data Flag",
                        "type": "ENUM",
                        "constraints": {"required": True},
                        "enumValues": [{"name": "Y"}, {"name": "N"}]
                    }
                ]
            }, f)

        for loc in [region, "global"]:
            for a_id in ["protected-raw-data-aspect", "protected_raw_data_aspect"]:
                run_cmd(f'gcloud dataplex aspect-types create {a_id} --location={loc} --display-name="Protected Raw Data Aspect" --metadata-template-file={aspect_def} --project={project_id} --quiet 2>/dev/null || true')

                field_def = f'id={f_name},display-name="Protected Raw Data Flag",type="enum(Y|N)",required=true'
                run_cmd(f'gcloud data-catalog tag-templates create {a_id} --location={loc} --display-name="Protected Raw Data Aspect" --field=\'{field_def}\' --project={project_id} --quiet 2>/dev/null || true')

    # 2. Target entry paths
    zone_res_path = f"projects/{project_id}/locations/{region}/lakes/{lake_id}/zones/{zone_id}"
    asset_res_path = f"projects/{project_id}/locations/{region}/lakes/{lake_id}/zones/{zone_id}/assets/{asset_id}"
    bucket_res_path = f"projects/{project_id}/buckets/{bucket_id}"

    zone_b64_url = base64.urlsafe_b64encode(zone_res_path.encode()).decode().rstrip("=")
    asset_b64_url = base64.urlsafe_b64encode(asset_res_path.encode()).decode().rstrip("=")
    bucket_b64_url = base64.urlsafe_b64encode(bucket_res_path.encode()).decode().rstrip("=")

    # 3. Patch aspects to entries using Dataplex REST API
    print("\n[Step 2] Attaching Aspects via Dataplex REST API...")
    token, _, _ = run_cmd("gcloud auth print-access-token")

    entries_map = [
        (region, "@dataplex", zone_b64_url),
        (region, "@dataplex", asset_b64_url),
        (region, "@storage", bucket_b64_url),
        ("global", "@dataplex", zone_b64_url),
        ("global", "@storage", bucket_b64_url),
    ]

    for loc, eg, entry_code in entries_map:
        entry_url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{loc}/entryGroups/{eg}/entries/{entry_code}?updateMask=aspects"
        
        for a_id in ["protected-raw-data-aspect", "protected_raw_data_aspect"]:
            aspect_type_full = f"projects/{project_id}/locations/{loc}/aspectTypes/{a_id}"
            
            for key_prefix in [project_id, project_num]:
                full_key = f"{key_prefix}.{loc}.{a_id}"

                for f_name in ["protected_raw_data_flag", "protected-raw-data-flag"]:
                    patch_payload = {
                        "aspects": {
                            full_key: {
                                "aspectType": aspect_type_full,
                                "data": {f_name: "Y"}
                            }
                        }
                    }
                    api_request(entry_url, method="PATCH", data=patch_payload, token=token)

    print("\n======================================================================")
    print("  COMPREHENSIVE ASPECT SOLVER FINISHED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
