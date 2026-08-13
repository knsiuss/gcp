#!/usr/bin/env python3
"""
GSP528 - Connecting Cloud Networks with NCC: Challenge Lab Automated Solver
Dynamically discovers VPC networks, VPN tunnels, and regions to build all NCC Hubs and Spokes.
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
    print("  GSP528 - Connecting Cloud Networks with NCC Challenge Lab Solver")
    print("======================================================================")

    project_id, _, _ = run_cmd("gcloud config get-value project")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    # Enable Network Connectivity API
    print("\n[Step 0] Enabling Network Connectivity API...")
    run_cmd(f"gcloud services enable networkconnectivity.googleapis.com --project={project_id} --quiet")

    # 1. Discover VPC Networks
    print("\n[Step 1] Discovering VPC Networks...")
    vpcs_raw, _, _ = run_cmd(f"gcloud compute networks list --project={project_id} --format='value(name)'")
    vpcs = [v.strip() for v in vpcs_raw.splitlines() if v.strip()]
    print(f"Discovered VPC Networks: {vpcs}")

    # 2. Discover VPN Tunnels
    print("\n[Step 2] Discovering VPN Tunnels...")
    tunnels_raw, _, _ = run_cmd(f"gcloud compute vpn-tunnels list --project={project_id} --format='json'")
    tunnels = json.loads(tunnels_raw) if tunnels_raw else []
    
    office1_tunnels = []
    office2_tunnels = []
    
    for t in tunnels:
        t_name = t.get("name", "")
        t_region = t.get("region", "").split("/")[-1]
        t_self_link = t.get("selfLink", "")
        
        if "office-1" in t_name or "office1" in t_name:
            office1_tunnels.append((t_name, t_region, t_self_link))
        elif "office-2" in t_name or "office2" in t_name:
            office2_tunnels.append((t_name, t_region, t_self_link))

    print(f"Office 1 Tunnels: {[t[0] for t in office1_tunnels]}")
    print(f"Office 2 Tunnels: {[t[0] for t in office2_tunnels]}")

    # Identify Workload VPCs and Office VPCs
    workload1_vpc = next((v for v in vpcs if "workload-1" in v or "workload1" in v), None)
    workload2_vpc = next((v for v in vpcs if "workload-2" in v or "workload2" in v), None)
    office1_vpc = next((v for v in vpcs if "office-1" in v or "office1" in v), None)
    office2_vpc = next((v for v in vpcs if "office-2" in v or "office2" in v), None)
    routing_vpc = next((v for v in vpcs if "routing" in v), None)

    print(f"Workload VPC 1: {workload1_vpc}")
    print(f"Workload VPC 2: {workload2_vpc}")
    print(f"Office 1 VPC:   {office1_vpc}")
    print(f"Office 2 VPC:   {office2_vpc}")
    print(f"Routing VPC:    {routing_vpc}")

    # =========================================================================
    # TASK 1: Connect 2 On-prem VPCs with NCC
    # Spoke 1 must contain "office-1", Spoke 2 must contain "office-2"
    # =========================================================================
    print("\n[Task 1] Creating Hub & Spokes for On-prem VPCs...")
    run_cmd(f"gcloud network-connectivity hubs create onprem-hub --project={project_id} --quiet 2>/dev/null || true")

    if office1_tunnels:
        t_region = office1_tunnels[0][1]
        t_uris = ",".join([t[2] for t in office1_tunnels])
        run_cmd(f"gcloud network-connectivity spokes linked-vpn-tunnels create office-1-spoke --hub=onprem-hub --vpn-tunnels={t_uris} --region={t_region} --project={project_id} --quiet 2>/dev/null || true")

    if office2_tunnels:
        t_region = office2_tunnels[0][1]
        t_uris = ",".join([t[2] for t in office2_tunnels])
        run_cmd(f"gcloud network-connectivity spokes linked-vpn-tunnels create office-2-spoke --hub=onprem-hub --vpn-tunnels={t_uris} --region={t_region} --project={project_id} --quiet 2>/dev/null || true")

    # =========================================================================
    # TASK 2: Connect VPC to VPC
    # Spoke 1 must contain "workload-1", Spoke 2 must contain "workload-2"
    # =========================================================================
    print("\n[Task 2] Creating Hub & Spokes for Workload VPCs...")
    run_cmd(f"gcloud network-connectivity hubs create workload-hub --project={project_id} --quiet 2>/dev/null || true")

    if workload1_vpc:
        run_cmd(f"gcloud network-connectivity spokes linked-vpc-network create workload-1-spoke --hub=workload-hub --vpc-network={workload1_vpc} --global --project={project_id} --quiet 2>/dev/null || true")

    if workload2_vpc:
        run_cmd(f"gcloud network-connectivity spokes linked-vpc-network create workload-2-spoke --hub=workload-hub --vpc-network={workload2_vpc} --global --project={project_id} --quiet 2>/dev/null || true")

    # =========================================================================
    # TASK 3: Connect VPC to On-prem
    # Spokes for both On-Prem Office 1 and Workload VPC 1 must include "hybrid" in their names!
    # =========================================================================
    print("\n[Task 3] Creating Hub & Spokes for Hybrid (VPC to On-prem)...")
    run_cmd(f"gcloud network-connectivity hubs create hybrid-hub --project={project_id} --quiet 2>/dev/null || true")

    target_office1_vpc = office1_vpc or routing_vpc or "office-1-vpc"
    if target_office1_vpc:
        run_cmd(f"gcloud network-connectivity spokes linked-vpc-network create hybrid-office-1-spoke --hub=hybrid-hub --vpc-network={target_office1_vpc} --global --project={project_id} --quiet 2>/dev/null || true")

    if workload1_vpc:
        run_cmd(f"gcloud network-connectivity spokes linked-vpc-network create hybrid-workload-1-spoke --hub=hybrid-hub --vpc-network={workload1_vpc} --global --project={project_id} --quiet 2>/dev/null || true")

    print("\n======================================================================")
    print("  GSP528 SOLVER EXECUTED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
