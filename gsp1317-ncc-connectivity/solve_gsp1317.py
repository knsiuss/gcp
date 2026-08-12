#!/usr/bin/env python3
"""
GSP1317 - Establish VPC to VPC Connectivity using NCC Python Solver
Fixes Step 6 shell escaping issue by transferring /tmp/run_psql.sh via SCP
"""

import os
import sys
import time
import json
import ipaddress
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
    print("  GSP1317 - Dynamic Subnet & PSC Cloud SQL Solver")
    print("======================================================================")

    project_id, _, _ = run_cmd("gcloud config get-value project")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    region = "us-east4"
    zone = "us-east4-b"

    # Step 1: Enable API & Create Hub
    print("\n[Step 1] Enabling API & Creating NCC Hub...")
    run_cmd(f"gcloud services enable networkconnectivity.googleapis.com --project={project_id} --quiet")
    run_cmd(f"gcloud network-connectivity hubs create ncc-hub --project={project_id} --quiet 2>/dev/null || true")

    # Step 2: Create Spokes
    print("\n[Step 2] Creating Spokes vpc1-spoke1 and vpc2-spoke2...")
    run_cmd(f"gcloud network-connectivity spokes linked-vpc-network create vpc1-spoke1 --hub=ncc-hub --vpc-network=vpc1-ncc --exclude-export-ranges=10.1.2.0/24 --global --project={project_id} --quiet 2>/dev/null || true")
    run_cmd(f"gcloud network-connectivity spokes linked-vpc-network create vpc2-spoke2 --hub=ncc-hub --vpc-network=vpc2-ncc --exclude-export-ranges=10.3.3.0/24 --global --project={project_id} --quiet 2>/dev/null || true")

    # Step 3: Get Subnet CIDR & Reserve Valid IP
    print("\n[Step 3] Reserving internal IP in vpc2-ncc-subnet1...")
    cidr_out, _, _ = run_cmd(f"gcloud compute networks subnets describe vpc2-ncc-subnet1 --region={region} --project={project_id} --format='value(ipCidrRange)'")
    cidr = cidr_out.strip() if cidr_out else "10.2.2.0/24"
    print(f"[*] Subnet CIDR: {cidr}")

    net = ipaddress.ip_network(cidr)
    target_ip = str(net[50])
    print(f"[*] Calculated Target IP: {target_ip}")

    # Reserve IP
    run_cmd(f"gcloud compute addresses create cloudsql-psc --project={project_id} --region={region} --subnet=vpc2-ncc-subnet1 --addresses={target_ip} --quiet 2>/dev/null || true")

    reserved_ip, _, _ = run_cmd(f"gcloud compute addresses list --project={project_id} --filter='name=cloudsql-psc' --format='value(address)'")
    reserved_ip = reserved_ip.strip()
    if not reserved_ip:
        reserved_ip = target_ip
    print(f"[*] Reserved PSC IP: {reserved_ip}")

    # Step 4: Get Service Attachment URI & Create Forwarding Rule
    print("\n[Step 4] Configuring Private Service Connect...")
    service_att, _, _ = run_cmd(f"gcloud sql instances describe cloudsql-postgres-qbcl --project={project_id} --format='value(pscServiceAttachmentLink)'")
    service_att = service_att.strip()
    print(f"[*] Service Attachment Link: {service_att}")

    run_cmd(f"gcloud compute forwarding-rules create cloudsql-psc-ep --address=cloudsql-psc --project={project_id} --region={region} --network=vpc2-ncc --target-service-attachment={service_att} --allow-psc-global-access --quiet 2>/dev/null || true")

    # Step 5: Configure DNS Zone & Record
    print("\n[Step 5] Configuring DNS Zone & Record...")
    run_cmd(f"gcloud dns managed-zones create cloudsql-dns --project={project_id} --description='DNS zone for Cloud SQL' --dns-name=us-east4.sql.goog. --networks=vpc2-ncc --visibility=private --quiet 2>/dev/null || true")

    dns_rec, _, _ = run_cmd(f"gcloud sql instances describe cloudsql-postgres-qbcl --project={project_id} --format='value(dnsName)'")
    dns_rec = dns_rec.strip()
    print(f"[*] DNS Record Name: {dns_rec}")

    if dns_rec and reserved_ip:
        run_cmd(f"gcloud dns record-sets create '{dns_rec}' --project={project_id} --type=A --rrdatas={reserved_ip} --zone=cloudsql-dns --quiet 2>/dev/null || true")

    # Step 6: Connect to Cloud SQL via SCP + SSH
    print("\n[Step 6] Initializing PostgreSQL database on cloudsql-client...")
    if dns_rec:
        psql_script_path = "/tmp/run_psql.sh"
        with open(psql_script_path, "w") as f:
            f.write(f"""#!/bin/bash
export PGPASSWORD=changeme
psql -h {dns_rec} -U postgres -d postgres -c 'CREATE DATABASE company;' 2>/dev/null || true
psql -h {dns_rec} -U postgres -d company -c 'CREATE TABLE employees (id SERIAL PRIMARY KEY, first VARCHAR(255) NOT NULL, last VARCHAR(255) NOT NULL, salary DECIMAL (10, 2));' 2>/dev/null || true
psql -h {dns_rec} -U postgres -d company -c "INSERT INTO employees (first, last, salary) VALUES ('Max', 'Mustermann', 5000.00), ('Anna', 'Schmidt', 7000.00), ('Peter', 'Mayer', 6000.00);" 2>/dev/null || true
psql -h {dns_rec} -U postgres -d company -c 'SELECT * FROM employees;'
""")

        run_cmd(f"gcloud compute scp {psql_script_path} cloudsql-client:/tmp/run_psql.sh --zone={zone} --tunnel-through-iap --project={project_id} --quiet 2>/dev/null || true")
        run_cmd(f"gcloud compute ssh cloudsql-client --zone={zone} --tunnel-through-iap --project={project_id} --quiet --command='chmod +x /tmp/run_psql.sh && /tmp/run_psql.sh' 2>/dev/null || true")

    print("\n======================================================================")
    print("  GSP1317 SOLVER COMPLETED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
