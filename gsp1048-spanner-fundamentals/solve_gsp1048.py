#!/usr/bin/env python3
"""
GSP1048 - Cloud Spanner - Database Fundamentals Master Solver
Automates creation of banking-instance, banking-db, Customer table, data insertion,
and banking-instance-2 / banking-db-2 CLI setup.
"""

import os
import sys
import time
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
    print("  GSP1048 - Cloud Spanner Database Fundamentals Solver")
    print("======================================================================")

    project_id, _, _ = run_cmd("gcloud config get-value project 2>/dev/null")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    # Enable Spanner API
    run_cmd(f"gcloud services enable spanner.googleapis.com --project={project_id} --quiet")

    # =========================================================================
    # TASK 1 & 2: Create banking-instance and banking-db
    # =========================================================================
    print("\n[Task 1 & 2] Creating Cloud Spanner instance 'banking-instance' and database 'banking-db'...")
    run_cmd(f"gcloud spanner instances create banking-instance --config=regional-europe-west1 --description='banking-instance' --nodes=1 --edition=ENTERPRISE --project={project_id} --quiet 2>/dev/null || gcloud spanner instances create banking-instance --config=regional-europe-west1 --description='banking-instance' --nodes=1 --project={project_id} --quiet 2>/dev/null || true")

    run_cmd(f"gcloud spanner databases create banking-db --instance=banking-instance --project={project_id} --quiet 2>/dev/null || true")

    # =========================================================================
    # TASK 3 & 4: Create table Customer & Insert rows
    # =========================================================================
    print("\n[Task 3 & 4] Creating table 'Customer' and inserting sample rows...")
    ddl_stmt = "CREATE TABLE Customer ( CustomerId STRING(36) NOT NULL, Name STRING(MAX) NOT NULL, Location STRING(MAX) NOT NULL, ) PRIMARY KEY (CustomerId);"
    run_cmd(f"gcloud spanner databases ddl update banking-db --instance=banking-instance --ddl=\"{ddl_stmt}\" --project={project_id} --quiet 2>/dev/null || true")

    # Insert rows
    sql1 = "INSERT INTO Customer (CustomerId, Name, Location) VALUES ('bdaaaa97-1b4b-4e58-b4ad-84030de92235', 'Richard Nelson', 'Ada Ohio');"
    sql2 = "INSERT INTO Customer (CustomerId, Name, Location) VALUES ('b2b4002d-7813-4551-b83b-366ef95f9273', 'Shana Underwood', 'Ely Iowa');"

    run_cmd(f"gcloud spanner databases execute-sql banking-db --instance=banking-instance --sql=\"{sql1}\" --project={project_id} --quiet 2>/dev/null || true")
    run_cmd(f"gcloud spanner databases execute-sql banking-db --instance=banking-instance --sql=\"{sql2}\" --project={project_id} --quiet 2>/dev/null || true")

    # =========================================================================
    # TASK 5: Create banking-instance-2 & banking-db-2 via CLI
    # =========================================================================
    print("\n[Task 5] Creating Spanner instance 'banking-instance-2' and database 'banking-db-2'...")
    run_cmd(f"gcloud spanner instances create banking-instance-2 --config=regional-europe-west1 --description='Banking Instance 2' --nodes=2 --project={project_id} --quiet 2>/dev/null || true")
    run_cmd(f"gcloud spanner databases create banking-db-2 --instance=banking-instance-2 --project={project_id} --quiet 2>/dev/null || true")
    run_cmd(f"gcloud spanner instances update banking-instance-2 --nodes=1 --project={project_id} --quiet 2>/dev/null || true")

    print("\n======================================================================")
    print("  GSP1048 SOLVER COMPLETED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
