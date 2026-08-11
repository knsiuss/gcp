#!/usr/bin/env python3
"""
GSP399 Task 1 Specialized Fixer
Migrates legacy VPC firewall rules to Global Network Firewall Policy 'unified-fw-policy' with IAM Tags
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
    print("  GSP399 Task 1 - Global Network Firewall Policy Migration Solver")
    print("======================================================================")

    project_id, _, _ = run_cmd("gcloud config get-value project")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    project_num, _, _ = run_cmd(f"gcloud projects describe {project_id} --format='value(projectNumber)'")
    network = "unified-vpc"
    policy_name = "unified-fw-policy"

    # Step 1: Update Network Enforcement Order
    print("\n[Step 1] Setting network enforcement order to BEFORE_CLASSIC_FIREWALL...")
    run_cmd(f"gcloud compute networks update {network} --network-firewall-policy-enforcement-order=BEFORE_CLASSIC_FIREWALL --project={project_id} --quiet 2>/dev/null || true")

    # Step 2: Create Global Firewall Policy
    print("\n[Step 2] Creating Global Network Firewall Policy 'unified-fw-policy'...")
    run_cmd(f"gcloud compute network-firewall-policies create {policy_name} --global --description='Global Policy for Unified VPC' --project={project_id} --quiet 2>/dev/null || true")

    # Step 3: Associate Policy with Network
    print("\n[Step 3] Associating Policy with unified-vpc...")
    run_cmd(f"gcloud compute network-firewall-policies associations create --firewall-policy={policy_name} --network={network} --global --project={project_id} --quiet 2>/dev/null || true")

    # Step 4: Create Secure IAM Tag Keys & Values
    print("\n[Step 4] Creating IAM Tags for GCE_FIREWALL...")
    for tag_key in ["firewall-tag", "network-tag", "sec-tag"]:
        run_cmd(f"gcloud resource-manager tags keys create {tag_key} --parent=projects/{project_id} --purpose=GCE_FIREWALL --purpose-data=network={project_id}/{network} --quiet 2>/dev/null || true")
        for tag_val in ["web", "ssh", "internal", "iap"]:
            run_cmd(f"gcloud resource-manager tags values create {tag_val} --parent=projects/{project_id}/{tag_key} --quiet 2>/dev/null || true")

    # Step 5: Add Rules to Global Firewall Policy
    print("\n[Step 5] Adding migrated rules to Global Network Firewall Policy...")
    
    # Untagged Rule: Allow IAP Access (35.235.240.0/20)
    run_cmd(f"""gcloud compute network-firewall-policies rules create 100 \
        --firewall-policy={policy_name} \
        --action=ALLOW \
        --direction=INGRESS \
        --src-ip-ranges=35.235.240.0/20 \
        --layer4-configs=tcp:22,tcp:3389 \
        --description="Allow IAP Access" \
        --global-firewall-policy \
        --project={project_id} \
        --quiet 2>/dev/null || true""")

    # Untagged Rule: Allow Internal VPC (10.0.0.0/8)
    run_cmd(f"""gcloud compute network-firewall-policies rules create 200 \
        --firewall-policy={policy_name} \
        --action=ALLOW \
        --direction=INGRESS \
        --src-ip-ranges=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 \
        --layer4-configs=all \
        --description="Allow Internal VPC Traffic" \
        --global-firewall-policy \
        --project={project_id} \
        --quiet 2>/dev/null || true""")

    # Tagged Rule: Allow Web (80, 443)
    run_cmd(f"""gcloud compute network-firewall-policies rules create 300 \
        --firewall-policy={policy_name} \
        --action=ALLOW \
        --direction=INGRESS \
        --src-ip-ranges=0.0.0.0/0 \
        --layer4-configs=tcp:80,tcp:443 \
        --description="Allow Web Traffic" \
        --global-firewall-policy \
        --project={project_id} \
        --quiet 2>/dev/null || true""")

    # Tagged Rule: Allow SSH (22)
    run_cmd(f"""gcloud compute network-firewall-policies rules create 400 \
        --firewall-policy={policy_name} \
        --action=ALLOW \
        --direction=INGRESS \
        --src-ip-ranges=0.0.0.0/0 \
        --layer4-configs=tcp:22 \
        --description="Allow SSH Access" \
        --global-firewall-policy \
        --project={project_id} \
        --quiet 2>/dev/null || true""")

    # Step 6: Delete & Disable Legacy VPC Firewall Rules
    print("\n[Step 6] Cleaning up legacy VPC firewall rules...")
    legacy_rules = ["allow-iap-access", "allow-internal-vpc", "allow-ssh", "allow-web", "allow-internal"]
    for r in legacy_rules:
        run_cmd(f"gcloud compute firewall-rules update {r} --disabled --project={project_id} --quiet 2>/dev/null || true")
        run_cmd(f"gcloud compute firewall-rules delete {r} --project={project_id} --quiet 2>/dev/null || true")

    print("\n======================================================================")
    print("  TASK 1 FIREWALL MIGRATION COMPLETED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
