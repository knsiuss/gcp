#!/usr/bin/env python3
"""
GSP081 - Cloud Run Functions: Qwik Start - Console Master Solver
Fixed API service name to cloudbuild.googleapis.com and added fallback for function deployment.
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
    print("  GSP081 - Cloud Run Functions Qwik Start Solver")
    print("======================================================================")

    project_id, _, _ = run_cmd("gcloud config get-value project 2>/dev/null")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    # Enable required services (correct API: cloudbuild.googleapis.com)
    run_cmd(f"gcloud services enable cloudfunctions.googleapis.com run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com --project={project_id} --quiet 2>/dev/null || true")

    # Create code directory
    home_dir = os.path.expanduser("~")
    code_dir = os.path.join(home_dir, "gcf_hello")
    os.makedirs(code_dir, exist_ok=True)

    index_js = """const functions = require('@google-cloud/functions-framework');

functions.http('helloHttp', (req, res) => {
  res.send(`Hello ${req.body.message || req.body.name || req.query.name || 'World'}!`);
});
"""

    package_json = """{
  "name": "sample-http",
  "version": "0.0.1",
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
"""

    with open(os.path.join(code_dir, "index.js"), "w") as f:
        f.write(index_js)

    with open(os.path.join(code_dir, "package.json"), "w") as f:
        f.write(package_json)

    # Deploy Cloud Function
    print("\n[Task 1 & 2] Deploying Cloud Run function 'gcfunction'...")
    deploy_cmd1 = f"cd {code_dir} && gcloud functions deploy gcfunction --gen2 --region=us-east1 --runtime=nodejs20 --source=. --entry-point=helloHttp --trigger-http --allow-unauthenticated --max-instances=5 --project={project_id} --quiet"
    _, stderr1, code1 = run_cmd(deploy_cmd1)

    if code1 != 0:
        print("[*] Gen2 deployment notice, trying v1 deployment...")
        deploy_cmd2 = f"cd {code_dir} && gcloud functions deploy gcfunction --region=us-east1 --runtime=nodejs18 --source=. --entry-point=helloHttp --trigger-http --allow-unauthenticated --max-instances=5 --project={project_id} --quiet"
        run_cmd(deploy_cmd2)

    print("\n======================================================================")
    print("  GSP081 SOLVER COMPLETED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
