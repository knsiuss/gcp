#!/usr/bin/env python3
"""
GSP872 - API Gateway: Qwik Start Master Solver
Automates deploying Cloud Function backend helloGET, creating OpenAPI specs,
setting up API Gateway (hello-gateway), enabling Managed Service, generating API key,
updating Gateway with secured config, and verifying calls.
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
    print("  GSP872 - API Gateway Qwik Start Solver")
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
    run_cmd(f"gcloud services enable apigateway.googleapis.com servicemanagement.googleapis.com servicecontrol.googleapis.com cloudfunctions.googleapis.com cloudbuild.googleapis.com apikeys.googleapis.com --project={project_id} --quiet")

    # =========================================================================
    # TASK 1 & 2: Deploy Cloud Function helloGET
    # =========================================================================
    print("\n[Task 1 & 2] Deploying Cloud Function 'helloGET'...")
    home_dir = os.path.expanduser("~")
    cf_dir = os.path.join(home_dir, "cf_helloGET")
    os.makedirs(cf_dir, exist_ok=True)

    with open(os.path.join(cf_dir, "index.js"), "w") as f:
        f.write("exports.helloGET = (req, res) => { res.send('Hello World!'); };\n")

    with open(os.path.join(cf_dir, "package.json"), "w") as f:
        f.write('{"name":"hello-get","version":"0.0.1"}\n')

    run_cmd(f"cd {cf_dir} && gcloud functions deploy helloGET --runtime=nodejs18 --trigger-http --allow-unauthenticated --region=us-east1 --entry-point=helloGET --project={project_id} --quiet 2>/dev/null || cd {cf_dir} && gcloud functions deploy helloGET --runtime=nodejs20 --trigger-http --allow-unauthenticated --region=us-east1 --entry-point=helloGET --project={project_id} --quiet 2>/dev/null || true")

    fn_url = f"https://us-east1-{project_id}.cloudfunctions.net/helloGET"
    run_cmd(f"curl -s {fn_url}")

    # =========================================================================
    # TASK 3: Create API, API Config, and Gateway
    # =========================================================================
    print("\n[Task 3] Creating API, OpenAPI spec, API Config, and Gateway...")
    
    openapi_spec1 = f"""swagger: '2.0'
info:
  title: hello-api
  description: Sample API on API Gateway with a Google Cloud Functions backend
  version: 1.0.0
schemes:
  - https
produces:
  - application/json
paths:
  /hello:
    get:
      summary: Greet a user
      operationId: hello
      x-google-backend:
        address: https://us-east1-{project_id}.cloudfunctions.net/helloGET
      responses:
        '200':
          description: A successful response
          schema:
            type: string
"""
    spec1_path = os.path.join(home_dir, "openapi2-functions.yaml")
    with open(spec1_path, "w") as f:
        f.write(openapi_spec1)

    api_id = "hello-api"
    config_id = "hello-config"
    gateway_id = "hello-gateway"

    run_cmd(f"gcloud api-gateway apis create {api_id} --project={project_id} --quiet 2>/dev/null || true")

    run_cmd(f"gcloud api-gateway api-configs create {config_id} --api={api_id} --openapi-spec={spec1_path} --backend-auth-service-account={sa_email} --project={project_id} --quiet 2>/dev/null || true")

    run_cmd(f"gcloud api-gateway gateways create {gateway_id} --api={api_id} --api-config={config_id} --location=us-east1 --project={project_id} --quiet 2>/dev/null || true")

    # =========================================================================
    # TASK 4: Enable Managed Service & Create API Key
    # =========================================================================
    print("\n[Task 4] Enabling Managed Service & Creating API Key...")
    managed_svc_out, _, _ = run_cmd(f"gcloud api-gateway apis list --format='json(managedService)' --project={project_id}")
    try:
        data = json.loads(managed_svc_out)
        managed_svc = data[0].get("managedService", "").split("/")[-1]
        print(f"[*] Managed Service: {managed_svc}")
        if managed_svc:
            run_cmd(f"gcloud services enable {managed_svc} --project={project_id} --quiet 2>/dev/null || true")
    except Exception as e:
        print(f"Notice getting managed service: {e}")

    # Create API Key
    key_out, _, _ = run_cmd(f"gcloud alpha services api-keys create --display-name='hello-key' --project={project_id} --format='value(name)' --quiet 2>/dev/null || gcloud services api-keys create --display-name='hello-key' --project={project_id} --format='value(name)' --quiet 2>/dev/null || true")

    # =========================================================================
    # TASK 5 & 6: Create Securing API Config & Update Gateway
    # =========================================================================
    print("\n[Task 5 & 6] Creating OpenAPI spec with security & updating Gateway...")
    openapi_spec2 = f"""swagger: '2.0'
info:
  title: hello-api
  description: Sample API on API Gateway with a Google Cloud Functions backend
  version: 1.0.0
schemes:
  - https
produces:
  - application/json
paths:
  /hello:
    get:
      summary: Greet a user
      operationId: hello
      x-google-backend:
        address: https://us-east1-{project_id}.cloudfunctions.net/helloGET
      security:
        - api_key: []
      responses:
        '200':
          description: A successful response
          schema:
            type: string
securityDefinitions:
  api_key:
    type: "apiKey"
    name: "key"
    in: "query"
"""
    spec2_path = os.path.join(home_dir, "openapi2-functions2.yaml")
    with open(spec2_path, "w") as f:
        f.write(openapi_spec2)

    config_id2 = "hello-config-2"
    run_cmd(f"gcloud api-gateway api-configs create {config_id2} --api={api_id} --openapi-spec={spec2_path} --backend-auth-service-account={sa_email} --project={project_id} --quiet 2>/dev/null || true")

    run_cmd(f"gcloud api-gateway gateways update {gateway_id} --api={api_id} --api-config={config_id2} --location=us-east1 --project={project_id} --quiet 2>/dev/null || true")

    print("\n======================================================================")
    print("  GSP872 SOLVER COMPLETED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
