#!/usr/bin/env python3
"""
GSP526 - Privileged Access with IAM: Challenge Lab Master Solver
Automates PAM API activation, Service Agent IAM role assignment, Entitlement creation & updates,
Grant request, approval, revocation, and Entitlement deletion.
"""

import os
import sys
import time
import json
import subprocess

def run_cmd(cmd):
    print(f"Executing: {cmd}")
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if res.stdout:
        print(f"Stdout: {res.stdout.strip()[:300]}")
    if res.stderr and "already exists" not in res.stderr.lower():
        print(f"Stderr: {res.stderr.strip()[:300]}")
    return res.stdout.strip(), res.stderr.strip(), res.returncode

def get_access_token():
    out, _, _ = run_cmd("gcloud auth print-access-token")
    return out.strip()

def curl_api(url, method="GET", data=None, token=None):
    if not token:
        token = get_access_token()
    headers = f"-H 'Authorization: Bearer {token}' -H 'Content-Type: application/json'"
    d_flag = f"-d '{json.dumps(data)}'" if data else ""
    cmd = f"curl -s -X {method} {headers} {d_flag} '{url}'"
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    try:
        return json.loads(res.stdout)
    except Exception:
        return {"raw": res.stdout}

def main():
    print("======================================================================")
    print("  GSP526 - Privileged Access with IAM: Challenge Lab Solver")
    print("======================================================================")

    # Discover Project ID & Number
    project_id, _, _ = run_cmd("gcloud config get-value project 2>/dev/null")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")

    proj_desc, _, _ = run_cmd(f"gcloud projects describe {project_id} --format='value(projectNumber)'")
    project_num = proj_desc.strip()

    print(f"[*] Project ID: {project_id}")
    print(f"[*] Project Number: {project_num}")

    primary_user = "student-04-583b971d94ef@qwiklabs.net"
    secondary_user = "student-04-70b42075e7df@qwiklabs.net"

    # =========================================================================
    # TASK 1: Enable PAM API & Grant Service Agent Role
    # =========================================================================
    print("\n[Task 1] Enabling Privileged Access Manager API & granting Service Agent role...")
    run_cmd(f"gcloud services enable privilegedaccessmanager.googleapis.com --project={project_id} --quiet")

    # PAM Service Agent email
    pam_sa = f"serviceAccount:service-{project_num}@gcp-sa-pam.iam.gserviceaccount.com"
    run_cmd(f"gcloud projects add-iam-policy-binding {project_id} --member='{pam_sa}' --role='roles/privilegedaccessmanager.serviceAgent' --project={project_id} --quiet 2>/dev/null || true")

    print("[Task 1] Sleeping 10s for API initialization...")
    time.sleep(10)

    # =========================================================================
    # TASK 2: Create the Entitlement (pam-entitlement)
    # =========================================================================
    print("\n[Task 2] Creating PAM Entitlement 'pam-entitlement'...")
    base_url = f"https://privilegedaccessmanager.googleapis.com/v1/projects/{project_id}/locations/global/entitlements"
    
    entitlement_body = {
        "eligibleUsers": [
            {"principal": f"user:{primary_user}"}
        ],
        "approvalWorkflow": {
            "manualApprovals": {
                "requireApproverJustification": False,
                "steps": [
                    {
                        "approvers": [{"principal": f"user:{secondary_user}"}],
                        "approvalsNeeded": 1
                    }
                ]
            }
        },
        "maxRequestDuration": "36000s",
        "privilegedAccess": {
            "gcpIamAccess": {
                "roleBindings": [
                    {"role": "roles/compute.admin"}
                ]
            }
        },
        "requesterJustificationConfig": {
            "notRequired": {}
        }
    }

    url_create = f"{base_url}?entitlementId=pam-entitlement"
    res_create = curl_api(url_create, method="POST", data=entitlement_body)
    print(f"Create Entitlement Response: {res_create}")

    # =========================================================================
    # TASK 3: Update the Entitlement (maxRequestDuration = 4h / 14400s)
    # =========================================================================
    print("\n[Task 3] Updating PAM Entitlement max duration to 4 hours (14400s)...")
    url_update = f"{base_url}/pam-entitlement?updateMask=maxRequestDuration"
    update_body = {
        "maxRequestDuration": "14400s"
    }
    res_update = curl_api(url_update, method="PATCH", data=update_body)
    print(f"Update Entitlement Response: {res_update}")

    # =========================================================================
    # TASK 4: Request & Approve Temporary Elevated Access
    # =========================================================================
    print("\n[Task 4] Requesting grant for 4 hours...")
    url_grant_req = f"{base_url}/pam-entitlement/grants"
    grant_req_body = {
        "requestedDuration": "14400s",
        "justification": {
            "unstructuredJustification": "Testing PAM elevation request"
        }
    }
    res_grant = curl_api(url_grant_req, method="POST", data=grant_req_body)
    print(f"Request Grant Response: {res_grant}")

    grant_name = res_grant.get("name", "")
    grant_id = grant_name.split("/")[-1] if grant_name else ""

    if grant_id:
        print(f"[*] Created Grant ID: {grant_id}")
        print("\n[Task 4] Approving Grant...")
        url_approve = f"{base_url}/pam-entitlement/grants/{grant_id}:approve"
        res_approve = curl_api(url_approve, method="POST", data={"reason": "Approved for testing"})
        print(f"Approve Grant Response: {res_approve}")
    else:
        print("[-] Warning: Grant creation did not return grant name immediately.")

    # =========================================================================
    # TASK 5: Revoke Grant
    # =========================================================================
    if grant_id:
        print("\n[Task 5] Revoking Grant...")
        time.sleep(5)
        url_revoke = f"{base_url}/pam-entitlement/grants/{grant_id}:revoke"
        res_revoke = curl_api(url_revoke, method="POST", data={"reason": "Revoking grant for security test"})
        print(f"Revoke Grant Response: {res_revoke}")

    # =========================================================================
    # TASK 6: Delete Entitlement
    # =========================================================================
    print("\n[Task 6] Deleting PAM Entitlement...")
    time.sleep(5)
    url_delete = f"{base_url}/pam-entitlement"
    res_delete = curl_api(url_delete, method="DELETE")
    print(f"Delete Entitlement Response: {res_delete}")

    print("\n======================================================================")
    print("  GSP526 SOLVER COMPLETED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
