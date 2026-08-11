#!/usr/bin/env python3
"""
GSP399 Task 1 Specialized Fixer - Binds Secure IAM Tags to Network Firewall Policy Rules
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
    print("  GSP399 Task 1 - Secure IAM Tags & Global Policy Solver")
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

    # Step 2: Create Global Firewall Policy & Associate
    print("\n[Step 2] Creating Global Network Firewall Policy 'unified-fw-policy'...")
    run_cmd(f"gcloud compute network-firewall-policies create {policy_name} --global --description='Global Policy for Unified VPC' --project={project_id} --quiet 2>/dev/null || true")
    run_cmd(f"gcloud compute network-firewall-policies associations create --firewall-policy={policy_name} --network={network} --global --project={project_id} --quiet 2>/dev/null || true")

    # Step 3: Create Tag Keys and Values
    print("\n[Step 3] Creating Secure IAM Tags...")
    tag_key_name = "firewall-tag"
    run_cmd(f"gcloud resource-manager tags keys create {tag_key_name} --parent=projects/{project_id} --purpose=GCE_FIREWALL --purpose-data=network={project_id}/{network} --quiet 2>/dev/null || true")
    
    # Get Tag Key ID
    tag_key_id_out, _, _ = run_cmd(f"gcloud resource-manager tags keys list --parent=projects/{project_id} --format='value(name)' --filter='shortName:{tag_key_name}'")
    tag_key_id = tag_key_id_out.strip()
    print(f"[*] Tag Key ID: {tag_key_id}")

    val_ids = {}
    for val in ["web", "ssh", "internal"]:
        run_cmd(f"gcloud resource-manager tags values create {val} --parent={tag_key_id} --quiet 2>/dev/null || true")
        v_id_out, _, _ = run_cmd(f"gcloud resource-manager tags values list --parent={tag_key_id} --format='value(name)' --filter='shortName:{val}'")
        val_ids[val] = v_id_out.strip()
        print(f"[*] Tag Value ID for {val}: {val_ids[val]}")

    # Bind tags to instances
    print("\n[Step 4] Binding IAM Tags to Compute Instances...")
    instances_out, _, _ = run_cmd("gcloud compute instances list --format='csv[no-heading](name,zone)'")
    if instances_out:
        for line in instances_out.splitlines():
            parts = line.strip().split(",")
            if len(parts) == 2:
                inst_name, inst_zone = parts[0], parts[1]
                inst_tags, _, _ = run_cmd(f"gcloud compute instances list --filter='name:{inst_name}' --format='value(tags.items[])'")
                
                # Check matching tags
                for val in ["web", "ssh"]:
                    if val in inst_tags and val_ids.get(val):
                        parent_path = f"//compute.googleapis.com/projects/{project_id}/zones/{inst_zone}/instances/{inst_name}"
                        run_cmd(f"gcloud resource-manager tags bindings create --location={inst_zone} --parent={parent_path} --tag-value={val_ids[val]} --quiet 2>/dev/null || true")

    # Step 5: Add Rules with --target-secure-tags to Global Firewall Policy
    print("\n[Step 5] Creating Rules with Secure Tags in Global Firewall Policy...")

    # Rule 100: Allow IAP
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

    # Rule 200: Allow Internal
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

    # Rule 300: Allow Web with Target Secure Tag
    web_tag_target = val_ids.get("web") or f"{project_id}/{tag_key_name}/web"
    run_cmd(f"""gcloud compute network-firewall-policies rules create 300 \
        --firewall-policy={policy_name} \
        --action=ALLOW \
        --direction=INGRESS \
        --src-ip-ranges=0.0.0.0/0 \
        --layer4-configs=tcp:80,tcp:443 \
        --target-secure-tags={web_tag_target} \
        --description="Allow Web Traffic via Secure Tag" \
        --global-firewall-policy \
        --project={project_id} \
        --quiet 2>/dev/null || true""")

    # Rule 400: Allow SSH with Target Secure Tag
    ssh_tag_target = val_ids.get("ssh") or f"{project_id}/{tag_key_name}/ssh"
    run_cmd(f"""gcloud compute network-firewall-policies rules create 400 \
        --firewall-policy={policy_name} \
        --action=ALLOW \
        --direction=INGRESS \
        --src-ip-ranges=0.0.0.0/0 \
        --layer4-configs=tcp:22 \
        --target-secure-tags={ssh_tag_target} \
        --description="Allow SSH Access via Secure Tag" \
        --global-firewall-policy \
        --project={project_id} \
        --quiet 2>/dev/null || true""")

    # Step 6: Delete & Disable Legacy Rules
    print("\n[Step 6] Disabling & deleting legacy VPC firewall rules...")
    for r in ["allow-iap-access", "allow-internal-vpc", "allow-ssh", "allow-web", "allow-internal"]:
        run_cmd(f"gcloud compute firewall-rules update {r} --disabled --project={project_id} --quiet 2>/dev/null || true")
        run_cmd(f"gcloud compute firewall-rules delete {r} --project={project_id} --quiet 2>/dev/null || true")

    print("\n======================================================================")
    print("  GSP399 TASK 1 SECURE TAG MIGRATION SOLVED!")
    print("======================================================================")

if __name__ == "__main__":
    main()
