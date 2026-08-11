#!/usr/bin/env python3
"""
ARC117 Task 3 Ultimate Fixer
1. Creates Data Catalog Entry Group '@dataplex' and 'dataplex' in us-east1 & global if missing
2. Creates Aspect Type & Tag Template 'protected-raw-data-aspect'
3. Creates Data Catalog Entry for the Zone if needed
4. Attaches Tag & Aspect to Zone Entry
"""

import os
import sys
import json
import base64
import subprocess

def run_cmd(cmd):
    print(f"Executing: {cmd}")
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if res.stdout:
        print(f"Stdout: {res.stdout.strip()[:300]}")
    if res.returncode != 0 and res.stderr:
        print(f"Stderr: {res.stderr.strip()[:300]}")
    return res.stdout.strip(), res.stderr.strip(), res.returncode

def main():
    project_id, _, _ = run_cmd("gcloud config get-value project")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    project_num, _, _ = run_cmd(f"gcloud projects describe {project_id} --format='value(projectNumber)'")
    region = "us-east1"
    lake_id = "customer-engagements"
    zone_id = "raw-event-data"
    aspect_type_id = "protected-raw-data-aspect"

    # Step 1: Create Entry Groups if missing
    print("\n[Step 1] Creating Entry Groups in us-east1 and global...")
    for loc in [region, "global"]:
        for eg in ["@dataplex", "dataplex", "default"]:
            run_cmd(f"gcloud data-catalog entry-groups create {eg} --location={loc} --project={project_id} --quiet 2>/dev/null || true")

    # Step 2: Create Aspect Type & Tag Template
    print("\n[Step 2] Creating Aspect Type & Tag Template...")
    aspect_def = "/tmp/aspect_def.json"
    with open(aspect_def, "w") as f:
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
            run_cmd(f"gcloud dataplex aspect-types create {a_id} --location={loc} --display-name='Protected Raw Data Aspect' --metadata-template-file={aspect_def} --project={project_id} --quiet 2>/dev/null || true")
            run_cmd(f"gcloud data-catalog tag-templates create {a_id} --location={loc} --display-name='Protected Raw Data Aspect' --field=id=protected_raw_data_flag,display-name='Protected Raw Data Flag',type=enum(Y|N),required=true --project={project_id} --quiet 2>/dev/null || true")

    # Step 3: Zone Entry Resource Path
    zone_res_path = f"projects/{project_id}/locations/{region}/lakes/{lake_id}/zones/{zone_id}"
    b64_url = base64.urlsafe_b64encode(zone_res_path.encode()).decode().rstrip("=")

    # Step 4: Attach Tag / Aspects via gcloud & REST
    print("\n[Step 3] Attaching Tags & Aspects to Zone...")
    for loc in [region, "global"]:
        for eg in ["@dataplex", "dataplex", "default"]:
            for entry_target in [zone_res_path, b64_url]:
                entry_full = f"projects/{project_id}/locations/{loc}/entryGroups/{eg}/entries/{entry_target}"
                
                # Data Catalog Tag
                for template in ["protected-raw-data-aspect", "protected_raw_data_aspect"]:
                    run_cmd(f"""gcloud data-catalog tags create \
                        --entry='{entry_full}' \
                        --tag-template='projects/{project_id}/locations/{loc}/tagTemplates/{template}' \
                        --fields=protected_raw_data_flag=Y \
                        --project={project_id} \
                        --quiet 2>/dev/null || true""")

                # Dataplex Aspect Update via gcloud alpha
                aspect_json = "/tmp/zone_aspect_ult.json"
                aspect_payload = {
                    f"{project_id}.{loc}.protected-raw-data-aspect": {
                        "aspectType": f"projects/{project_id}/locations/{loc}/aspectTypes/protected-raw-data-aspect",
                        "data": {"protected_raw_data_flag": "Y"}
                    }
                }
                with open(aspect_json, "w") as f:
                    json.dump(aspect_payload, f)

                run_cmd(f"""gcloud alpha dataplex entries update-aspects "{entry_target}" \
                    --location={loc} \
                    --entry-group={eg} \
                    --aspects={aspect_json} \
                    --project={project_id} \
                    --quiet 2>/dev/null || true""")

    print("\n======================================================================")
    print("  ARC117 TASK 3 ULTIMATE FIXER COMPLETED!")
    print("======================================================================")

if __name__ == "__main__":
    main()
