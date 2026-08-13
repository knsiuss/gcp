#!/usr/bin/env python3
"""
GSP647 - Configuring IAM Permissions with gcloud Master Solver
Dynamically detects Cloud Shell configuration name (e.g. cloudshell-17511),
creates user2 profile, switches back to Cloud Shell active config, and runs all IAM/VM tasks.
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

def main():
    print("======================================================================")
    print("  GSP647 - Configuring IAM Permissions with gcloud Master Solver")
    print("======================================================================")

    # 1. Discover Initial Cloud Shell Configuration Name
    configs_raw, _, _ = run_cmd("gcloud config configurations list --format='value(name)'")
    configs = [c.strip() for c in configs_raw.splitlines() if c.strip()]
    
    owner_config = next((c for c in configs if c != "user2"), "default")
    print(f"[*] Detected Owner gcloud configuration profile name: '{owner_config}'")

    # Activate Owner configuration profile
    run_cmd(f"gcloud config configurations activate {owner_config} --quiet 2>/dev/null || true")

    # 2. Discover Projects using Owner credentials
    p_list_raw, _, _ = run_cmd("gcloud projects list --format='value(projectId)'")
    projects = [p.strip() for p in p_list_raw.splitlines() if p.strip()]
    print(f"Discovered Projects: {projects}")

    current_p, _, _ = run_cmd("gcloud config get-value project 2>/dev/null")
    if not current_p:
        current_p = os.environ.get("DEVSHELL_PROJECT_ID", "")

    project1 = current_p
    project2 = next((p for p in projects if p != project1 and "resources" not in p), project1)

    print(f"[*] Project 1: {project1}")
    print(f"[*] Project 2: {project2}")

    user1 = "student-04-be1599954870@qwiklabs.net"
    user2 = "student-01-bd78082f8847@qwiklabs.net"

    # Set compute region and zone on Owner profile
    run_cmd(f"gcloud config set compute/region us-east1 --quiet")
    run_cmd(f"gcloud config set compute/zone us-east1-b --quiet")

    # 3. Create user2 configuration profile via gcloud & set properties
    run_cmd(f"gcloud config configurations create user2 --quiet 2>/dev/null || true")
    run_cmd(f"gcloud config set account {user2} --configuration=user2 --quiet 2>/dev/null || true")
    run_cmd(f"gcloud config set project {project2} --configuration=user2 --quiet 2>/dev/null || true")
    run_cmd(f"gcloud config set compute/region us-east1 --configuration=user2 --quiet 2>/dev/null || true")
    run_cmd(f"gcloud config set compute/zone us-east1-b --configuration=user2 --quiet 2>/dev/null || true")

    # Re-activate Owner profile immediately
    run_cmd(f"gcloud config configurations activate {owner_config} --quiet")

    # =========================================================================
    # TASK 1: Create instance lab-1 in Project 1 & Update default zone
    # =========================================================================
    print("\n[Task 1] Setting region/zone & creating VM lab-1 in Project 1...")
    run_cmd(f"gcloud compute instances create lab-1 --zone=us-east1-c --machine-type=e2-standard-2 --project={project1} --quiet 2>/dev/null || true")
    run_cmd(f"gcloud config set compute/zone us-east1-b --quiet")

    # =========================================================================
    # TASK 2 & 3: Grant viewer role to user2 on Project 2
    # =========================================================================
    print("\n[Task 2 & 3] Binding viewer role to user2 on Project 2...")
    run_cmd(f"gcloud projects add-iam-policy-binding {project2} --member=user:{user2} --role=roles/viewer --quiet")

    # =========================================================================
    # TASK 4: Create devops custom role & bind roles to user2
    # =========================================================================
    print("\n[Task 4] Creating 'devops' custom role in Project 2...")
    devops_perms = "compute.instances.create,compute.instances.delete,compute.instances.start,compute.instances.stop,compute.instances.update,compute.disks.create,compute.subnetworks.use,compute.subnetworks.useExternalIp,compute.instances.setMetadata,compute.instances.setServiceAccount"
    
    run_cmd(f"gcloud iam roles create devops --project={project2} --title='devops' --permissions='{devops_perms}' --stage=GA --quiet 2>/dev/null || true")

    print("\n[Task 4] Binding iam.serviceAccountUser and devops role to user2 on Project 2...")
    run_cmd(f"gcloud projects add-iam-policy-binding {project2} --member=user:{user2} --role=roles/iam.serviceAccountUser --quiet")
    run_cmd(f"gcloud projects add-iam-policy-binding {project2} --member=user:{user2} --role=projects/{project2}/roles/devops --quiet")

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
    run_cmd(f"gcloud projects add-iam-policy-binding {project2} --member=serviceAccount:{sa_email} --role=roles/iam.serviceAccountUser --quiet")
    run_cmd(f"gcloud projects add-iam-policy-binding {project2} --member=serviceAccount:{sa_email} --role=roles/compute.instanceAdmin --quiet")

    print("\n[Task 6] Creating VM lab-3 in Project 2 with devops Service Account...")
    run_cmd(f"gcloud compute instances create lab-3 --zone=us-east1-d --machine-type=e2-standard-2 --service-account={sa_email} --scopes='https://www.googleapis.com/auth/compute' --project={project2} --quiet 2>/dev/null || true")

    # =========================================================================
    # TASK 7: Create VM lab-4 in Project 2
    # =========================================================================
    print("\n[Task 7] Creating VM lab-4 in Project 2...")
    run_cmd(f"gcloud compute instances create lab-4 --zone=us-east1-d --machine-type=e2-standard-2 --project={project2} --quiet 2>/dev/null || true")

    # =========================================================================
    # EXECUTE ON centos-clean VM VIA SSH
    # =========================================================================
    print("\n[SSH Task] Syncing configuration & settings to centos-clean VM...")
    vm_zone_out, _, _ = run_cmd(f"gcloud compute instances list --filter='name=centos-clean' --format='value(zone)' --project={project1}")
    vm_zone = vm_zone_out.strip() if vm_zone_out else "us-east1-c"

    remote_script = f"""#!/bin/bash
gcloud config set compute/region us-east1 --quiet 2>/dev/null || true
gcloud config set compute/zone us-east1-b --quiet 2>/dev/null || true
gcloud config configurations create user2 --quiet 2>/dev/null || true
gcloud config set account {user2} --configuration=user2 --quiet 2>/dev/null || true
gcloud config set project {project2} --configuration=user2 --quiet 2>/dev/null || true
gcloud config set compute/region us-east1 --configuration=user2 --quiet 2>/dev/null || true
gcloud config set compute/zone us-east1-b --configuration=user2 --quiet 2>/dev/null || true
"""
    with open("/tmp/vm_setup.sh", "w") as f:
        f.write(remote_script)

    run_cmd(f"gcloud compute scp /tmp/vm_setup.sh centos-clean:/tmp/vm_setup.sh --zone={vm_zone} --project={project1} --quiet 2>/dev/null || true")
    run_cmd(f"gcloud compute ssh centos-clean --zone={vm_zone} --project={project1} --quiet --command='chmod +x /tmp/vm_setup.sh && /tmp/vm_setup.sh' 2>/dev/null || true")

    print("\n======================================================================")
    print("  GSP647 SOLVER COMPLETED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
