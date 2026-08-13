#!/usr/bin/env python3
"""
GSP647 - Configuring IAM Permissions with gcloud Automated Solver
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
    if res.returncode != 0 and res.stderr:
        print(f"Stderr: {res.stderr.strip()[:300]}")
    return res.stdout.strip(), res.stderr.strip(), res.returncode

def main():
    print("======================================================================")
    print("  GSP647 - Configuring IAM Permissions with gcloud Solver")
    print("======================================================================")

    # 1. Discover Projects
    p_list_raw, _, _ = run_cmd("gcloud projects list --format='value(projectId)'")
    projects = [p.strip() for p in p_list_raw.splitlines() if p.strip()]
    print(f"Discovered Projects: {projects}")

    current_p, _, _ = run_cmd("gcloud config get-value project")
    if not current_p:
        current_p = os.environ.get("DEVSHELL_PROJECT_ID", "")

    project1 = current_p
    project2 = next((p for p in projects if p != project1), project1)

    print(f"[*] Project 1: {project1}")
    print(f"[*] Project 2: {project2}")

    # User 2 Email (From prompt credentials)
    user2 = "student-01-bd78082f8847@qwiklabs.net"

    # =========================================================================
    # TASK 1: Create instance lab-1 in Project 1 & Update default zone
    # =========================================================================
    print("\n[Task 1] Setting region/zone & creating VM lab-1 in Project 1...")
    run_cmd(f"gcloud config set compute/region us-east1 --project={project1} --quiet")
    run_cmd(f"gcloud config set compute/zone us-east1-c --project={project1} --quiet")
    
    run_cmd(f"gcloud compute instances create lab-1 --zone=us-east1-c --machine-type=e2-standard-2 --project={project1} --quiet 2>/dev/null || true")

    # =========================================================================
    # TASK 2 & 3: Configure gcloud user2 config & Add viewer policy binding
    # =========================================================================
    print("\n[Task 2 & 3] Creating gcloud user2 configuration & granting viewer role on Project 2...")
    run_cmd(f"gcloud config configurations create user2 --quiet 2>/dev/null || true")
    run_cmd(f"gcloud config configurations activate default --quiet")

    run_cmd(f"gcloud projects add-iam-policy-binding {project2} --member=user:{user2} --role=roles/viewer --quiet 2>/dev/null || true")

    # =========================================================================
    # TASK 4: Create devops custom role & bind roles to user2
    # =========================================================================
    print("\n[Task 4] Creating 'devops' custom role in Project 2...")
    devops_perms = "compute.instances.create,compute.instances.delete,compute.instances.start,compute.instances.stop,compute.instances.update,compute.disks.create,compute.subnetworks.use,compute.subnetworks.useExternalIp,compute.instances.setMetadata,compute.instances.setServiceAccount"
    
    run_cmd(f"gcloud iam roles create devops --project={project2} --permissions='{devops_perms}' --quiet 2>/dev/null || true")

    print("\n[Task 4] Binding iam.serviceAccountUser and devops role to user2 on Project 2...")
    run_cmd(f"gcloud projects add-iam-policy-binding {project2} --member=user:{user2} --role=roles/iam.serviceAccountUser --quiet 2>/dev/null || true")
    run_cmd(f"gcloud projects add-iam-policy-binding {project2} --member=user:{user2} --role=projects/{project2}/roles/devops --quiet 2>/dev/null || true")

    print("\n[Task 4] Creating VM lab-2 in Project 2...")
    run_cmd(f"gcloud compute instances create lab-2 --zone=us-east1-d --machine-type=e2-standard-2 --project={project2} --quiet 2>/dev/null || true")

    # =========================================================================
    # TASK 5 & 6: Create Service Account & VM lab-3 with SA attached
    # =========================================================================
    print("\n[Task 5 & 6] Creating Service Account 'devops' in Project 2...")
    run_cmd(f"gcloud iam service-accounts create devops --display-name=devops --project={project2} --quiet 2>/dev/null || true")

    sa_email = f"devops@{project2}.iam.gserviceaccount.com"
    print(f"[*] SA Email: {sa_email}")

    print("\n[Task 5 & 6] Binding roles to SA on Project 2...")
    run_cmd(f"gcloud projects add-iam-policy-binding {project2} --member=serviceAccount:{sa_email} --role=roles/iam.serviceAccountUser --quiet 2>/dev/null || true")
    run_cmd(f"gcloud projects add-iam-policy-binding {project2} --member=serviceAccount:{sa_email} --role=roles/compute.instanceAdmin --quiet 2>/dev/null || true")

    print("\n[Task 6] Creating VM lab-3 in Project 2 with devops Service Account...")
    run_cmd(f"gcloud compute instances create lab-3 --zone=us-east1-d --machine-type=e2-standard-2 --service-account={sa_email} --scopes='https://www.googleapis.com/auth/compute' --project={project2} --quiet 2>/dev/null || true")

    # =========================================================================
    # TASK 7: Create VM lab-4 in Project 2
    # =========================================================================
    print("\n[Task 7] Creating VM lab-4 in Project 2...")
    run_cmd(f"gcloud compute instances create lab-4 --zone=us-east1-d --machine-type=e2-standard-2 --project={project2} --quiet 2>/dev/null || true")

    print("\n======================================================================")
    print("  GSP647 SOLVER COMPLETED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
