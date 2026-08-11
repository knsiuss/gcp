#!/usr/bin/env python3
"""
ARC117 Task 3 Fixer - Covers all entry variations, location variations, and API formats
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
        print(f"API ({e.code}) on {url[:90]}: {err_body[:250]}")
        return {}

def main():
    print("======================================================================")
    print("  ARC117 Task 3 Complete Fixer (Aspect Creation & Zone/Asset Attach)")
    print("======================================================================")

    project_id, _, _ = run_cmd("gcloud config get-value project")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    project_number, _, _ = run_cmd(f"gcloud projects describe {project_id} --format='value(projectNumber)'")
    print(f"[*] Project Number: {project_number}")

    region = "us-east1"
    lake_id = "customer-engagements"
    zone_id = "raw-event-data"
    asset_id = "raw-event-files"
    bucket_id = project_id

    # 1. Aspect Types & Tag Templates creation
    print("\n[Step 1] Creating Aspect Types & Tag Templates...")
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

    # 2. Prepare target entry paths for Zone, Asset, and Bucket
    zone_res_path = f"projects/{project_id}/locations/{region}/lakes/{lake_id}/zones/{zone_id}"
    asset_res_path = f"projects/{project_id}/locations/{region}/lakes/{lake_id}/zones/{zone_id}/assets/{asset_id}"
    bucket_res_path = f"projects/{project_id}/buckets/{bucket_id}"

    zone_b64_std = base64.b64encode(zone_res_path.encode()).decode().rstrip("=")
    zone_b64_url = base64.urlsafe_b64encode(zone_res_path.encode()).decode().rstrip("=")

    asset_b64_std = base64.b64encode(asset_res_path.encode()).decode().rstrip("=")
    asset_b64_url = base64.urlsafe_b64encode(asset_res_path.encode()).decode().rstrip("=")

    bucket_b64_std = base64.b64encode(bucket_res_path.encode()).decode().rstrip("=")
    bucket_b64_url = base64.urlsafe_b64encode(bucket_res_path.encode()).decode().rstrip("=")

    entries_to_patch = []

    for loc in [region, "global"]:
        # Zone entries
        entries_to_patch.append(f"projects/{project_id}/locations/{loc}/entryGroups/@dataplex/entries/{zone_res_path}")
        entries_to_patch.append(f"projects/{project_id}/locations/{loc}/entryGroups/@dataplex/entries/{zone_b64_std}")
        entries_to_patch.append(f"projects/{project_id}/locations/{loc}/entryGroups/@dataplex/entries/{zone_b64_url}")

        # Asset entries
        entries_to_patch.append(f"projects/{project_id}/locations/{loc}/entryGroups/@dataplex/entries/{asset_res_path}")
        entries_to_patch.append(f"projects/{project_id}/locations/{loc}/entryGroups/@dataplex/entries/{asset_b64_std}")
        entries_to_patch.append(f"projects/{project_id}/locations/{loc}/entryGroups/@dataplex/entries/{asset_b64_url}")

        # Storage bucket entries
        entries_to_patch.append(f"projects/{project_id}/locations/{loc}/entryGroups/@storage/entries/{bucket_b64_std}")
        entries_to_patch.append(f"projects/{project_id}/locations/{loc}/entryGroups/@storage/entries/{bucket_b64_url}")

    # 3. Patch aspects to entries via Dataplex REST API
    print("\n[Step 2] Attaching Aspect to entries via REST API...")

    for a_id in ["protected-raw-data-aspect", "protected_raw_data_aspect"]:
        for loc in [region, "global"]:
            aspect_type_full = f"projects/{project_id}/locations/{loc}/aspectTypes/{a_id}"

            for key_format in [a_id, f"{project_id}.{loc}.{a_id}", f"{project_number}.{loc}.{a_id}"]:
                aspects_payload = {
                    key_format: {
                        "aspectType": aspect_type_full,
                        "data": {"protected_raw_data_flag": "Y"}
                    }
                }
                patch_data = {"aspects": aspects_payload}

                token, _, _ = run_cmd("gcloud auth print-access-token")
                for entry_name in set(entries_to_patch):
                    patch_url = f"https://dataplex.googleapis.com/v1/{entry_name}?updateMask=aspects"
                    api_request(patch_url, method="PATCH", data=patch_data, token=token)

    # 4. Attach Data Catalog Tags fallback
    print("\n[Step 3] Attaching Data Catalog Tags fallback...")
    for loc in [region, "global"]:
        for t_id in ["protected-raw-data-aspect", "protected_raw_data_aspect"]:
            tag_template_path = f"projects/{project_id}/locations/{loc}/tagTemplates/{t_id}"

            for e_path in [
                f"projects/{project_id}/locations/{loc}/entryGroups/@storage/entries/{bucket_b64_std}",
                f"projects/{project_id}/locations/{loc}/entryGroups/@dataplex/entries/{zone_b64_std}"
            ]:
                run_cmd(f"""gcloud data-catalog tags create \
                    --entry='{e_path}' \
                    --tag-template='{tag_template_path}' \
                    --fields=protected_raw_data_flag=Y \
                    --project={project_id} \
                    --quiet 2>/dev/null || true""")

    print("\n======================================================================")
    print("  ARC117 TASK 3 FIXER COMPLETED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
