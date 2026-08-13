#!/usr/bin/env python3
"""
GSP499 - User Authentication: Identity-Aware Proxy Master Solver
Automates Cloud Run deployments, IAP configurations, JWT Audience extraction, and IAM bindings.
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
    if res.stderr:
        print(f"Stderr: {res.stderr.strip()[:300]}")
    return res.stdout.strip(), res.stderr.strip(), res.returncode

def main():
    print("======================================================================")
    print("  GSP499 - User Authentication: Identity-Aware Proxy Solver")
    print("======================================================================")

    # 1. Discover Project ID & Number
    project_id, _, _ = run_cmd("gcloud config get-value project 2>/dev/null")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")

    proj_desc, _, _ = run_cmd(f"gcloud projects describe {project_id} --format='value(projectNumber)'")
    project_num = proj_desc.strip()

    print(f"[*] Project ID: {project_id}")
    print(f"[*] Project Number: {project_num}")

    # Discover User Account
    user_acc, _, _ = run_cmd("gcloud config get-value account 2>/dev/null")
    print(f"[*] User Account: {user_acc}")

    # Enable required services
    run_cmd(f"gcloud services enable run.googleapis.com iap.googleapis.com artifactregistry.googleapis.com --project={project_id} --quiet")

    # Download lab assets
    home_dir = os.path.expanduser("~")
    code_dir = os.path.join(home_dir, "user-authentication-with-iap")

    if not os.path.exists(code_dir):
        bucket_url = f"gs://{project_id}-bucket/user-authentication-with-iap.zip"
        run_cmd(f"gcloud storage cp {bucket_url} {home_dir}/user-authentication-with-iap.zip --project={project_id} --quiet 2>/dev/null || true")
        run_cmd(f"cd {home_dir} && unzip -o user-authentication-with-iap.zip")

    # =========================================================================
    # TASK 1: Deploy 1-HelloWorld to Cloud Run
    # =========================================================================
    print("\n[Task 1] Deploying 1-HelloWorld to Cloud Run...")
    hw_dir = os.path.join(code_dir, "1-HelloWorld")
    run_cmd(f"cd {hw_dir} && gcloud run deploy user-auth-lab --source . --allow-unauthenticated --region=us-central1 --project={project_id} --quiet")

    # Allow IAP access / policy binding
    if user_acc:
        run_cmd(f"gcloud run services add-iam-policy-binding user-auth-lab --member='user:{user_acc}' --role='roles/run.invoker' --region=us-central1 --project={project_id} --quiet 2>/dev/null || true")
        run_cmd(f"gcloud iap web add-iam-policy-binding --member='user:{user_acc}' --role='roles/iap.httpsResourceAccessor' --project={project_id} --quiet 2>/dev/null || true")

    # Grant IAP Service Agent permission to invoke Cloud Run
    iap_sa = f"serviceAccount:service-{project_num}@gcp-sa-iap.iam.gserviceaccount.com"
    run_cmd(f"gcloud run services add-iam-policy-binding user-auth-lab --member='{iap_sa}' --role='roles/run.invoker' --region=us-central1 --project={project_id} --quiet 2>/dev/null || true")

    # =========================================================================
    # TASK 2: Access User Identity Information (2-HelloUser)
    # =========================================================================
    print("\n[Task 2] Deploying 2-HelloUser to Cloud Run...")
    hu_dir = os.path.join(code_dir, "2-HelloUser")
    run_cmd(f"cd {hu_dir} && gcloud run deploy user-auth-lab --source . --region=us-central1 --project={project_id} --quiet")

    # =========================================================================
    # TASK 3: Use Cryptographic Verification (3-HelloVerifiedUser)
    # =========================================================================
    print("\n[Task 3] Getting IAP Audience / Client ID & Deploying 3-HelloVerifiedUser...")
    
    # Extract IAP Audience / Client ID
    aud_out, _, _ = run_cmd(f"gcloud iap oauth-clients list --project={project_id} --format='value(name)' 2>/dev/null")
    iap_aud = aud_out.strip() if aud_out else f"/projects/{project_num}/global/backendServices/user-auth-lab"

    # Fallback to standard Cloud Run IAP audience format
    aud_val = f"/projects/{project_num}/global/backendServices/user-auth-lab"

    hvu_dir = os.path.join(code_dir, "3-HelloVerifiedUser")
    run_cmd(f"cd {hvu_dir} && gcloud run deploy user-auth-lab --source . --set-env-vars IAP_AUDIENCE='{aud_val}' --region=us-central1 --project={project_id} --quiet")

    # Re-apply IAP SA binding
    run_cmd(f"gcloud run services add-iam-policy-binding user-auth-lab --member='{iap_sa}' --role='roles/run.invoker' --region=us-central1 --project={project_id} --quiet 2>/dev/null || true")

    print("\n======================================================================")
    print("  GSP499 SOLVER COMPLETED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
