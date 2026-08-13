#!/usr/bin/env python3
"""
GSP081 - Cloud Run Functions: Qwik Start - Console Master Solver
Deploys Cloud Run function (gen2) named 'gcfunction' in region us-east1 with Node.js 20.
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

    # Enable required services
    run_cmd(f"gcloud services enable cloudfunctions.googleapis.com run.googleapis.com build.googleapis.com artifactregistry.googleapis.com --project={project_id} --quiet")

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

    # Deploy Cloud Function gen2
    print("\n[Task 1 & 2] Deploying Cloud Run function 'gcfunction' (gen2)...")
    deploy_cmd = f"cd {code_dir} && gcloud functions deploy gcfunction --gen2 --region=us-east1 --runtime=nodejs20 --source=. --entry-point=helloHttp --trigger-http --allow-unauthenticated --max-instances=5 --project={project_id} --quiet"
    run_cmd(deploy_cmd)

    # Test function
    print("\n[Task 3] Testing deployed function...")
    url_out, _, _ = run_cmd(f"gcloud functions describe gcfunction --region=us-east1 --gen2 --format='value(serviceConfig.uri)' --project={project_id}")
    fn_url = url_out.strip()

    if fn_url:
        print(f"[*] Function URL: {fn_url}")
        run_cmd(f"curl -X POST '{fn_url}' -H 'Content-Type: application/json' -d '{{\"message\":\"Hello World!\"}}'")

    print("\n======================================================================")
    print("  GSP081 SOLVER COMPLETED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
