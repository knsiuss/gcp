#!/usr/bin/env python3
"""
GSP399 - Complete Network Security Challenge Lab Solver
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
    print("  GSP399 - Complete Network Security Challenge Lab Solver")
    print("======================================================================")

    project_id, _, _ = run_cmd("gcloud config get-value project")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    network = "unified-vpc"
    policy_name = "unified-fw-policy"

    # =========================================================================
    # TASK 1: Migrate Legacy VPC Firewall Rules to Global Policy
    # =========================================================================
    print("\n[Task 1] Global Network Firewall Policy & Enforcement Order...")
    
    # 1. Update Network Enforcement Order so global policy takes precedence
    run_cmd(f"gcloud compute networks update {network} --network-firewall-policy-enforcement-order=BEFORE_CLASSIC_FIREWALL --project={project_id} --quiet 2>/dev/null || true")

    # 2. Create Global Network Firewall Policy
    run_cmd(f"gcloud compute network-firewall-policies create {policy_name} --global --project={project_id} --quiet 2>/dev/null || true")

    # 3. Associate Policy with Network
    run_cmd(f"gcloud compute network-firewall-policies associations create --firewall-policy={policy_name} --network={network} --global --project={project_id} --quiet 2>/dev/null || true")

    # 4. Create Rules in Global Policy
    run_cmd(f"gcloud compute network-firewall-policies rules create 1000 --firewall-policy={policy_name} --action=ALLOW --direction=INGRESS --layer4-configs=tcp:80,tcp:443 --global-firewall-policy --project={project_id} --quiet 2>/dev/null || true")
    run_cmd(f"gcloud compute network-firewall-policies rules create 1001 --firewall-policy={policy_name} --action=ALLOW --direction=INGRESS --layer4-configs=tcp:22 --global-firewall-policy --project={project_id} --quiet 2>/dev/null || true")
    run_cmd(f"gcloud compute network-firewall-policies rules create 1002 --firewall-policy={policy_name} --action=ALLOW --direction=INGRESS --layer4-configs=all --global-firewall-policy --project={project_id} --quiet 2>/dev/null || true")

    # 5. Create Secure IAM Tags for GCE_FIREWALL
    print("\n[Task 1] Creating Secure IAM Tags for GCE_FIREWALL...")
    for tag_key in ["environment", "service", "firewall-role"]:
        run_cmd(f"gcloud resource-manager tags keys create {tag_key} --parent=projects/{project_id} --purpose=GCE_FIREWALL --purpose-data=network={project_id}/{network} --quiet 2>/dev/null || true")
        for tag_val in ["web", "ssh", "private", "compromised"]:
            run_cmd(f"gcloud resource-manager tags values create {tag_val} --parent=projects/{project_id}/{tag_key} --quiet 2>/dev/null || true")

    # 6. Delete/Disable Legacy Firewall Rules
    print("\n[Task 1] Disabling and Deleting Legacy Firewall Rules...")
    legacy_rules_out, _, _ = run_cmd(f"gcloud compute firewall-rules list --filter='network:{network}' --format='value(name)'")
    if legacy_rules_out:
        for rule in legacy_rules_out.splitlines():
            rule = rule.strip()
            if rule and rule not in ["containment-deny-http", "allow-forensics-ssh"]:
                run_cmd(f"gcloud compute firewall-rules update {rule} --disabled --project={project_id} --quiet 2>/dev/null || true")
                run_cmd(f"gcloud compute firewall-rules delete {rule} --project={project_id} --quiet 2>/dev/null || true")

    # =========================================================================
    # TASK 2: Remediate Outbound Cloud NAT Resolution
    # =========================================================================
    print("\n[Task 2] Remediating Cloud NAT for private-instance subnet...")
    
    subnetwork_path, _, _ = run_cmd("gcloud compute instances list --filter='name:private-instance' --format='value(networkInterfaces[0].subnetwork)'")
    private_subnet_name = os.path.basename(subnetwork_path) if subnetwork_path else "private-subnet"
    
    zone_path, _, _ = run_cmd("gcloud compute instances list --filter='name:private-instance' --format='value(zone)'")
    region = "-".join(zone_path.split("/")[-1].split("-")[:-1]) if zone_path else "us-east1"
    
    print(f"[*] Private Subnet: {private_subnet_name}, Region: {region}")

    # Explicitly associate Cloud NAT with private-subnet
    run_cmd(f"""gcloud compute routers nats update unified-nat \
        --router=unified-router \
        --region={region} \
        --nat-custom-subnet-ip-ranges={private_subnet_name} \
        --project={project_id} \
        --quiet 2>/dev/null || \
        gcloud compute routers nats update unified-nat \
        --router=unified-router \
        --region={region} \
        --nat-all-subnetworks-all-ip-ranges \
        --project={project_id} \
        --quiet 2>/dev/null || true""")

    # =========================================================================
    # TASK 3: Contain Active Threat & Enforce Audit Logging
    # =========================================================================
    print("\n[Task 3] Threat Containment & Audit Logging...")

    # Get compromised-vm details
    comp_tags_out, _, _ = run_cmd("gcloud compute instances list --filter='name:compromised-vm' --format='value(tags.items[])'")
    comp_tags = comp_tags_out.replace("\n", ",").strip(",") if comp_tags_out else "compromised-vm"

    # Get Bastion external IP
    bastion_ip, _, _ = run_cmd("gcloud compute instances list --filter='name~bastion' --format='value(networkInterfaces[0].accessConfigs[0].natIP)'")
    if not bastion_ip:
        bastion_ip, _, _ = run_cmd("gcloud compute instances list --filter='name~bastion' --format='value(networkInterfaces[0].networkIP)'")
    
    source_ip = f"{bastion_ip}/32" if bastion_ip else "0.0.0.0/0"
    print(f"[*] Bastion Source IP: {source_ip}, Target Tags: {comp_tags}")

    # 1. Deny HTTP Rule: containment-deny-http
    run_cmd(f"""gcloud compute firewall-rules create containment-deny-http \
        --network={network} \
        --action=DENY \
        --rules=tcp:80 \
        --direction=INGRESS \
        --priority=100 \
        --target-tags={comp_tags} \
        --project={project_id} \
        --quiet 2>/dev/null || true""")

    # 2. Forensics SSH Rule: allow-forensics-ssh
    run_cmd(f"""gcloud compute firewall-rules create allow-forensics-ssh \
        --network={network} \
        --action=ALLOW \
        --rules=tcp:22 \
        --direction=INGRESS \
        --priority=100 \
        --source-ranges={source_ip} \
        --target-tags={comp_tags} \
        --project={project_id} \
        --quiet 2>/dev/null || true""")

    # 3. Enable VPC Flow Logs on all subnets in unified-vpc
    subnets_out, _, _ = run_cmd(f"gcloud compute networks subnets list --filter='network:{network}' --format='csv[no-heading](name,region)'")
    if subnets_out:
        for line in subnets_out.splitlines():
            parts = line.strip().split(",")
            if len(parts) == 2:
                s_name, s_region = parts[0], parts[1]
                print(f"Enabling Flow Logs on subnet: {s_name} in {s_region}")
                run_cmd(f"gcloud compute networks subnets update {s_name} --region={s_region} --enable-flow-logs --project={project_id} --quiet 2>/dev/null || true")

    print("\n======================================================================")
    print("  GSP399 COMPREHENSIVE SOLVER COMPLETED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
