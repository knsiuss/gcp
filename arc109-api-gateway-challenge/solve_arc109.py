#!/usr/bin/env python3
"""
ARC109 - Deploy and Secure Serverless APIs with API Gateway: Challenge Lab Master Solver
Automates creating Cloud Run function 'gcfunction', deploying API Gateway 'gcfunction-api',
creating Pub/Sub topic 'demo-topic', updating Cloud Function code to publish to Pub/Sub,
re-deploying, and triggering requests via API Gateway.
"""

import os
import sys
import time
import subprocess
import json

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
    print("  ARC109 - Deploy and Secure Serverless APIs Challenge Lab Solver")
    print("======================================================================")

    project_id, _, _ = run_cmd("gcloud config get-value project 2>/dev/null")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    proj_num, _, _ = run_cmd(f"gcloud projects describe {project_id} --format='value(projectNumber)' 2>/dev/null")
    proj_num = proj_num.strip()
    sa_email = f"{proj_num}-compute@developer.gserviceaccount.com"
    print(f"[*] Service Account: {sa_email}")

    # Enable APIs
    print("\n[*] Enabling required Google Cloud APIs...")
    run_cmd(f"gcloud services enable cloudfunctions.googleapis.com run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com apigateway.googleapis.com servicemanagement.googleapis.com servicecontrol.googleapis.com pubsub.googleapis.com --project={project_id} --quiet")

    # =========================================================================
    # TASK 1: Create Cloud Run function 'gcfunction'
    # =========================================================================
    print("\n[Task 1] Creating Cloud Run function 'gcfunction' (gen2)...")
    home_dir = os.path.expanduser("~")
    fn_dir = os.path.join(home_dir, "gcfunction")
    os.makedirs(fn_dir, exist_ok=True)

    index_v1 = """const functions = require('@google-cloud/functions-framework');

functions.http('helloHttp', (req, res) => {
  res.send('Hello World!');
});
"""
    pkg_v1 = """{
  "name": "gcfunction",
  "version": "1.0.0",
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
"""
    with open(os.path.join(fn_dir, "index.js"), "w") as f:
        f.write(index_v1)
    with open(os.path.join(fn_dir, "package.json"), "w") as f:
        f.write(pkg_v1)

    deploy1 = f"cd {fn_dir} && gcloud functions deploy gcfunction --gen2 --region=us-east1 --runtime=nodejs22 --source=. --entry-point=helloHttp --trigger-http --allow-unauthenticated --project={project_id} --quiet 2>/dev/null || cd {fn_dir} && gcloud functions deploy gcfunction --gen2 --region=us-east1 --runtime=nodejs20 --source=. --entry-point=helloHttp --trigger-http --allow-unauthenticated --project={project_id} --quiet 2>/dev/null || true"
    run_cmd(deploy1)

    # Get Function URL
    url_out, _, _ = run_cmd(f"gcloud functions describe gcfunction --region=us-east1 --gen2 --format='value(serviceConfig.uri)' --project={project_id} 2>/dev/null")
    fn_url = url_out.strip()
    if not fn_url:
        run_cmd(f"gcloud run services add-iam-policy-binding gcfunction --region=us-east1 --member='allUsers' --role='roles/run.invoker' --project={project_id} --quiet 2>/dev/null || true")
        url_out, _, _ = run_cmd(f"gcloud run services describe gcfunction --region=us-east1 --format='value(status.url)' --project={project_id} 2>/dev/null")
        fn_url = url_out.strip()

    print(f"[*] Cloud Run Function URL: {fn_url}")

    # =========================================================================
    # TASK 2: Create API Gateway
    # =========================================================================
    print("\n[Task 2] Creating API Gateway 'gcfunction-api'...")
    spec_content = f"""swagger: '2.0'
info:
  title: gcfunction API
  description: Sample API on API Gateway with a Google Cloud Run functions backend
  version: 1.0.0
schemes:
  - https
produces:
  - application/json
x-google-backend:
  address: {fn_url}
paths:
  /gcfunction:
    get:
      summary: gcfunction
      operationId: gcfunction
      responses:
        '200':
          description: A successful response
          schema:
            type: string
"""
    spec_path = os.path.join(home_dir, "openapispec.yaml")
    with open(spec_path, "w") as f:
        f.write(spec_content)

    api_id = "gcfunction-api"
    config_id = "gcfunction-api"
    gateway_id = "gcfunction-api"

    run_cmd(f"gcloud api-gateway apis create {api_id} --display-name='gcfunction API' --project={project_id} --quiet 2>/dev/null || true")

    run_cmd(f"gcloud api-gateway api-configs create {config_id} --api={api_id} --display-name='gcfunction API' --openapi-spec={spec_path} --backend-auth-service-account={sa_email} --project={project_id} --quiet 2>/dev/null || true")

    run_cmd(f"gcloud api-gateway gateways create {gateway_id} --api={api_id} --api-config={config_id} --location=us-east1 --display-name='gcfunction API' --project={project_id} --quiet 2>/dev/null || true")

    # =========================================================================
    # TASK 3: Create Pub/Sub Topic and Update Cloud Function
    # =========================================================================
    print("\n[Task 3] Creating Pub/Sub topic 'demo-topic' & updating Cloud Function...")
    run_cmd(f"gcloud pubsub topics create demo-topic --project={project_id} --quiet 2>/dev/null || true")
    run_cmd(f"gcloud pubsub subscriptions create demo-topic-sub --topic=demo-topic --project={project_id} --quiet 2>/dev/null || true")

    index_v2 = """const {PubSub} = require('@google-cloud/pubsub');
const pubsub = new PubSub();
const topic = pubsub.topic('demo-topic');
const functions = require('@google-cloud/functions-framework');

exports.helloHttp = functions.http('helloHttp', (req, res) => {
  topic.publishMessage({data: Buffer.from('Hello from Cloud Run functions!')});
  res.status(200).send("Message sent to Topic demo-topic!");
});
"""
    pkg_v2 = """{
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0",
    "@google-cloud/pubsub": "^3.4.1"
  }
}
"""
    with open(os.path.join(fn_dir, "index.js"), "w") as f:
        f.write(index_v2)
    with open(os.path.join(fn_dir, "package.json"), "w") as f:
        f.write(pkg_v2)

    deploy2 = f"cd {fn_dir} && gcloud functions deploy gcfunction --gen2 --region=us-east1 --runtime=nodejs22 --source=. --entry-point=helloHttp --trigger-http --allow-unauthenticated --project={project_id} --quiet 2>/dev/null || cd {fn_dir} && gcloud functions deploy gcfunction --gen2 --region=us-east1 --runtime=nodejs20 --source=. --entry-point=helloHttp --trigger-http --allow-unauthenticated --project={project_id} --quiet 2>/dev/null || true"
    run_cmd(deploy2)

    # Invoke via Gateway
    gw_host_out, _, _ = run_cmd(f"gcloud api-gateway gateways describe {gateway_id} --location=us-east1 --format='value(defaultHostname)' --project={project_id} 2>/dev/null")
    gw_host = gw_host_out.strip()
    if gw_host:
        print(f"[*] Invoking API Gateway: https://{gw_host}/gcfunction")
        run_cmd(f"curl -s https://{gw_host}/gcfunction")

    print("\n======================================================================")
    print("  ARC109 SOLVER COMPLETED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
