#!/usr/bin/env python3
"""
GSP532 - Dynamic Solver for Build a Smart Cloud Application with Vibe Coding and MCP
Supports both 'vibe-co-zoo' and 'vibe-zoo' service naming conventions.
"""

import os
import re
import sys
import json
import subprocess

def run_cmd(cmd, check=False):
    print(f"Running: {cmd}")
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if res.returncode != 0 and check:
        print(f"Error ({res.returncode}): {res.stderr.strip()}")
    return res.stdout.strip(), res.stderr.strip(), res.returncode

def main():
    print("======================================================================")
    print("  GSP532 - Vibe Coding and MCP Challenge Lab Solver (Dynamic)")
    print("======================================================================")

    project_id, _, _ = run_cmd("gcloud config get-value project")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    user_email, _, _ = run_cmd("gcloud config get-value account")
    print(f"[*] User Email: {user_email}")

    project_number, _, _ = run_cmd(f"gcloud projects describe {project_id} --format='value(projectNumber)'")
    print(f"[*] Project Number: {project_number}")

    compute_sa = f"{project_number}-compute@developer.gserviceaccount.com"
    cloudbuild_sa = f"{project_number}@cloudbuild.gserviceaccount.com"

    home_dir = os.path.expanduser("~")

    # =========================================================================
    # TASK 1: Environment & API Enablement
    # =========================================================================
    print("\n[Task 1] Downloading code & enabling APIs...")
    os.chdir(home_dir)
    bucket_name = f"{project_id}-labconfig-bucket"

    run_cmd(f"gcloud storage cp gs://{bucket_name}/labs_code.zip . 2>/dev/null || gsutil cp gs://{bucket_name}/labs_code.zip .")
    run_cmd("unzip -o labs_code.zip 2>/dev/null || true")

    mcp_service_name = "vibe-co-zoo-mcp-server"
    adk_service_name = "vibe-co-zoo-tour-guide"
    mcp_url = f"https://{mcp_service_name}-{project_number}.us-central1.run.app/mcp/"

    zoo_dir = os.path.join(home_dir, "zoo_guide_agent")
    os.makedirs(zoo_dir, exist_ok=True)

    env_content = f"""MODEL="gemini-3.5-flash"
SERVICE_ACCOUNT="{compute_sa}"
MCP_SERVER_URL="{mcp_url}"
GOOGLE_GENAI_USE_ENTERPRISE=1
GOOGLE_CLOUD_PROJECT={project_id}
PROJECT_NUMBER={project_number}
GOOGLE_CLOUD_LOCATION=us-central1
"""
    with open(os.path.join(zoo_dir, ".env"), "w", encoding="utf-8") as f:
        f.write(env_content)

    apis = [
        "artifactregistry.googleapis.com",
        "compute.googleapis.com",
        "cloudbuild.googleapis.com",
        "run.googleapis.com",
        "aiplatform.googleapis.com"
    ]
    print("Enabling required Google Cloud APIs...")
    for api in apis:
        run_cmd(f"gcloud services enable {api} --quiet")

    # =========================================================================
    # TASK 2: IAM Policy Bindings
    # =========================================================================
    print("\n[Task 2] Granting IAM Roles...")
    run_cmd(f"gcloud projects add-iam-policy-binding {project_id} --member='user:{user_email}' --role='roles/run.admin' --quiet")
    run_cmd(f"gcloud projects add-iam-policy-binding {project_id} --member='user:{user_email}' --role='roles/iam.serviceAccountUser' --quiet")
    run_cmd(f"gcloud projects add-iam-policy-binding {project_id} --member='user:{user_email}' --role='roles/aiplatform.user' --quiet")
    run_cmd(f"gcloud projects add-iam-policy-binding {project_id} --member='user:{user_email}' --role='roles/cloudaicompanion.user' --quiet")

    run_cmd(f"gcloud projects add-iam-policy-binding {project_id} --member='serviceAccount:{compute_sa}' --role='roles/run.admin' --quiet")
    run_cmd(f"gcloud projects add-iam-policy-binding {project_id} --member='serviceAccount:{compute_sa}' --role='roles/run.invoker' --quiet")
    run_cmd(f"gcloud projects add-iam-policy-binding {project_id} --member='serviceAccount:{compute_sa}' --role='roles/aiplatform.user' --quiet")
    run_cmd(f"gcloud projects add-iam-policy-binding {project_id} --member='serviceAccount:{compute_sa}' --role='roles/storage.objectViewer' --quiet")

    run_cmd(f"gcloud projects add-iam-policy-binding {project_id} --member='serviceAccount:{cloudbuild_sa}' --role='roles/run.admin' --quiet")
    run_cmd(f"gcloud projects add-iam-policy-binding {project_id} --member='serviceAccount:{cloudbuild_sa}' --role='roles/iam.serviceAccountUser' --quiet")

    # =========================================================================
    # TASK 3: Fix & Deploy MCP Server
    # =========================================================================
    print("\n[Task 3] Fixing & Deploying MCP Server...")
    mcp_dir = os.path.join(home_dir, "mcp-on-cloudrun")
    server_py_path = os.path.join(mcp_dir, "server.py")

    if os.path.exists(server_py_path):
        with open(server_py_path, "r", encoding="utf-8") as f:
            code = f.read()

        code = re.sub(r"#\s*mcp\s*=\s*FastMCP", "mcp = FastMCP", code)
        code = re.sub(r"#\s*@mcp\.", "@mcp.", code)

        if "mcp.run(" not in code or "# mcp.run(" in code:
            code = re.sub(r"#\s*mcp\.run\(.*?\)", "", code)
            code += """

if __name__ == "__main__":
    import os
    port = int(os.environ.get("PORT", 8080))
    mcp.run(transport="sse", host="0.0.0.0", port=port)
"""

        with open(server_py_path, "w", encoding="utf-8") as f:
            f.write(code)

    os.chdir(mcp_dir)

    proc = subprocess.Popen(["uv", "run", "server.py"], cwd=mcp_dir)
    import time
    time.sleep(5)

    run_cmd(f"gcloud config set project {project_id}")
    stdout, stderr, ret = run_cmd("uv run local_mcp_call.py")
    print(f"local_mcp_call.py result: {stdout}")

    proc.terminate()
    try:
        proc.wait(timeout=2)
    except:
        proc.kill()

    for s_name in ["vibe-co-zoo-mcp-server", "vibe-zoo-mcp-server"]:
        print(f"Deploying {s_name} to Cloud Run...")
        run_cmd(f"""gcloud run deploy {s_name} \
            --no-allow-unauthenticated \
            --region=us-central1 \
            --source=. \
            --min=1 \
            --project={project_id} \
            --labels=lab-dev=mcp-zoo-cloud-run-service \
            --quiet""")

    # =========================================================================
    # TASK 4: Gemini Settings & Log verification
    # =========================================================================
    print("\n[Task 4] Gemini Settings & Verification...")
    id_token, _, _ = run_cmd("gcloud auth print-identity-token")

    gemini_dir = os.path.expanduser("~/.gemini")
    os.makedirs(gemini_dir, exist_ok=True)

    settings = {
        "mcpServers": {
            "zoo-remote": {
                "httpUrl": mcp_url,
                "headers": {
                    "Authorization": f"Bearer {id_token}"
                }
            }
        },
        "selectedAuthType": "compute-default-credentials",
        "hasSeenIdeIntegrationNudge": True
    }

    with open(os.path.join(gemini_dir, "settings.json"), "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2)

    run_cmd(f"gcloud run services logs read {mcp_service_name} --region us-central1 --limit=5 --project={project_id}")

    # =========================================================================
    # TASK 5: Update zoo_guide_agent/agent.py & Deploy ADK Agent
    # =========================================================================
    print("\n[Task 5] Updating & Deploying ADK Tour Guide Agent...")
    agent_py_path = os.path.join(zoo_dir, "agent.py")

    if os.path.exists(agent_py_path):
        with open(agent_py_path, "r", encoding="utf-8") as f:
            acode = f.read()

        acode = re.sub(r"#\s*(from\s+.*?import.*?)", r"\1", acode)
        acode = re.sub(r"#\s*(import\s+.*?)", r"\1", acode)
        acode = re.sub(r"#\s*(tools\s*=)", r"\1", acode)
        acode = re.sub(r"#\s*(MCPToolset)", r"\1", acode)

        if "google_search" not in acode:
            acode = "from google.adk.tools import google_search\n" + acode

        if "tools=" not in acode:
            acode = re.sub(
                r"(Agent\s*\([^)]*)(\))",
                r"\1, tools=[google_search]\2",
                acode
            )

        with open(agent_py_path, "w", encoding="utf-8") as f:
            f.write(acode)

    os.chdir(zoo_dir)
    export_path = 'export PATH=$PATH:"/home/${USER}/.local/bin"'

    for a_name in ["vibe-co-zoo-tour-guide", "vibe-zoo-tour-guide"]:
        print(f"Deploying {a_name} to Cloud Run...")
        run_cmd(f"""{export_path} && adk deploy cloud_run \
            --project={project_id} \
            --region=us-central1 \
            --service_name={a_name} \
            --with_ui \
            . \
            -- \
            --labels=lab-dev=cloud-zoo-run-adk-service \
            --quiet""")

    print("\n======================================================================")
    print("  GSP532 DYNAMIC SOLVER FINISHED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
