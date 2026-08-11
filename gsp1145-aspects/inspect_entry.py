#!/usr/bin/env python3
"""
GSP1145 - Inspect Dataplex Entry Name & Location
"""

import os
import sys
import json
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
            return json.loads(res_text) if res_text else {}
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        print(f"HTTP ({e.code}) on {url}: {err_body}")
        return {}

def main():
    project_id, _, _ = run_cmd("gcloud config get-value project")
    token, _, _ = run_cmd("gcloud auth print-access-token")

    print(f"[*] Project ID: {project_id}")

    # Search in all locations
    for loc in ["global", "us-west1", "us", "us-central1"]:
        search_url = f"https://dataplex.googleapis.com/v1/projects/{project_id}/locations/{loc}:searchEntries"
        res = api_request(search_url, method="POST", data={"query": "customer_details"}, token=token)
        print(f"\n--- Search Location ({loc}) Results ---")
        print(json.dumps(res, indent=2))

if __name__ == "__main__":
    main()
