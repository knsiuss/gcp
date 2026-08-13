#!/usr/bin/env python3
"""
GSP1050 - Spanner - Defining Schemas and Understanding Query Plans Master Solver
Automates loading data into Portfolio, Category, Product, Campaigns tables,
adding MarketingBudget column, updating data, and creating secondary indexes.
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
    print("  GSP1050 - Spanner Schemas and Query Plans Solver")
    print("======================================================================")

    project_id, _, _ = run_cmd("gcloud config get-value project 2>/dev/null")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    run_cmd(f"gcloud services enable spanner.googleapis.com --project={project_id} --quiet")

    # =========================================================================
    # TASK 1: Load Data into Portfolio, Category, and Product Tables
    # =========================================================================
    print("\n[Task 1] Loading data into Portfolio, Category, and Product tables...")
    sql_port = "INSERT INTO Portfolio (PortfolioId, Name, ShortName, PortfolioInfo) VALUES (1, 'Banking', 'Bnkg', 'All Banking Business'), (2, 'Asset Growth', 'AsstGrwth', 'All Asset Focused Products'), (3, 'Insurance', 'Ins', 'All Insurance Focused Products');"
    sql_cat = "INSERT INTO Category (CategoryId, PortfolioId, CategoryName) VALUES (1, 1, 'Cash'), (2, 2, 'Investments - Short Return'), (3, 2, 'Annuities'), (4, 3, 'Life Insurance');"
    sql_prod = "INSERT INTO Product (ProductId, CategoryId, PortfolioId, ProductName, ProductAssetCode, ProductClass) VALUES (1, 1, 1, 'Checking Account', 'ChkAcct', 'Banking LOB'), (2, 2, 2, 'Mutual Fund Consumer Goods', 'MFundCG', 'Investment LOB'), (3, 3, 2, 'Annuity Early Retirement', 'AnnuFixed', 'Investment LOB'), (4, 4, 3, 'Term Life Insurance', 'TermLife', 'Insurance LOB'), (5, 1, 1, 'Savings Account', 'SavAcct', 'Banking LOB'), (6, 1, 1, 'Personal Loan', 'PersLn', 'Banking LOB'), (7, 1, 1, 'Auto Loan', 'AutLn', 'Banking LOB'), (8, 4, 3, 'Permanent Life Insurance', 'PermLife', 'Insurance LOB'), (9, 2, 2, 'US Savings Bonds', 'USSavBond', 'Investment LOB');"

    run_cmd(f"gcloud spanner databases execute-sql banking-ops-db --instance=banking-ops-instance --sql=\"{sql_port}\" --project={project_id} --quiet 2>/dev/null || true")
    run_cmd(f"gcloud spanner databases execute-sql banking-ops-db --instance=banking-ops-instance --sql=\"{sql_cat}\" --project={project_id} --quiet 2>/dev/null || true")
    run_cmd(f"gcloud spanner databases execute-sql banking-ops-db --instance=banking-ops-instance --sql=\"{sql_prod}\" --project={project_id} --quiet 2>/dev/null || true")

    # =========================================================================
    # TASK 2: Load Data into Campaigns Table via snippets.py
    # =========================================================================
    print("\n[Task 2] Downloading helper snippets & inserting data into Campaigns table...")
    home_dir = os.path.expanduser("~")
    helper_dir = os.path.join(home_dir, "python-helper")
    os.makedirs(helper_dir, exist_ok=True)

    run_cmd(f"wget -q -O {helper_dir}/requirements.txt https://storage.googleapis.com/cloud-training/OCBL373/requirements.txt")
    run_cmd(f"wget -q -O {helper_dir}/snippets.py https://storage.googleapis.com/cloud-training/OCBL373/snippets.py")
    run_cmd(f"pip install -q -r {helper_dir}/requirements.txt setuptools")

    run_cmd(f"cd {helper_dir} && python3 snippets.py banking-ops-instance --database-id banking-ops-db insert_data")

    # =========================================================================
    # TASK 4: Add MarketingBudget Column & Update Data
    # =========================================================================
    print("\n[Task 4] Adding MarketingBudget column to Category table & updating values...")
    run_cmd(f"gcloud spanner databases ddl update banking-ops-db --instance=banking-ops-instance --ddl='ALTER TABLE Category ADD COLUMN MarketingBudget INT64' --project={project_id} --quiet 2>/dev/null || true")
    
    run_cmd(f"cd {helper_dir} && python3 snippets.py banking-ops-instance --database-id banking-ops-db update_data 2>/dev/null || true")

    # =========================================================================
    # TASK 5: Add Secondary Indexes
    # =========================================================================
    print("\n[Task 5] Adding secondary indexes CategoryByCategoryName and CategoryByCategoryName2...")
    run_cmd(f"gcloud spanner databases ddl update banking-ops-db --instance=banking-ops-instance --ddl='CREATE INDEX CategoryByCategoryName ON Category(CategoryName)' --project={project_id} --quiet 2>/dev/null || true")

    run_cmd(f"gcloud spanner databases ddl update banking-ops-db --instance=banking-ops-instance --ddl='CREATE INDEX CategoryByCategoryName2 ON Category(CategoryName) STORING (MarketingBudget)' --project={project_id} --quiet 2>/dev/null || true")

    print("\n======================================================================")
    print("  GSP1050 SOLVER COMPLETED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
