#!/usr/bin/env python3
"""
GSP1145 - Find & Patch Dataplex Entry (Tries global, region, and search API)
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
            print(f"Success ({method}) on {url[:100]}")
            return json.loads(res_text) if res_text else {}
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        print(f"API ({e.code}) on {url[:100]}: {err_body[:200]}")
        return {}

def main():
    print("======================================================================")
    print("  GSP1145 - Find & Patch Dataplex Entry")
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

    token, _, _ = run_cmd("gcloud auth print-access-token")

    # 1. Search Dataplex entries across locations
    found_entries = []
    for loc in ["global", region, "us", "us-central1"]:
        search_url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{loc}:searchEntries"
        search_payload = {"query": "customer_details"}
        res = api_request(search_url, method="POST", data=search_payload, token=token)
        if "results" in res:
            for r in res["results"]:
                entry = r.get("entry", {})
                entry_name = entry.get("name", "")
                if entry_name:
                    found_entries.append(entry_name)
                    print(f"Found Dataplex Entry via Search ({loc}): {entry_name}")

    # Fallback entry names if search returns empty
    target_resource = f"projects/{project_id}/datasets/customers/tables/customer_details"
    b64_std = base64.b64encode(target_resource.encode()).decode().rstrip("=")
    b64_url = base64.urlsafe_b64encode(target_resource.encode()).decode().rstrip("=")

    for loc in ["global", region, "us"]:
        found_entries.append(f"projects/{project_id}/locations/{loc}/entryGroups/@bigquery/entries/{b64_std}")
        found_entries.append(f"projects/{project_id}/locations/{loc}/entryGroups/@bigquery/entries/{b64_url}")

    columns = ["zip", "state", "last_name", "country", "email", "latitude", "first_name", "city", "longitude"]

    # 2. Build aspects payload
    for aspect_id in ["protected_data_aspect", "protected-data-aspect"]:
        aspect_type_full = f"projects/{project_id}/locations/{region}/aspectTypes/{aspect_id}"
        full_key = f"{project_id}.{region}.{aspect_id}"

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

        # Try patching each candidate entry name
        for entry_name in set(found_entries):
            patch_url = f"https://dataplex.googleapis.com/v1/{entry_name}?updateMask=aspects"
            token, _, _ = run_cmd("gcloud auth print-access-token")
            api_request(patch_url, method="PATCH", data=patch_payload, token=token)

    print("\n======================================================================")
    print("  FINISH SEARCH & PATCH PROCESS!")
    print("======================================================================")

if __name__ == "__main__":
    main()
