#!/usr/bin/env python3
"""
GSP532 - Complete Fixer & Inspector for MCP Server and ADK Agent
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
    print("  GSP532 - Detailed Inspection & Fixer")
    print("======================================================================")

    project_id, _, _ = run_cmd("gcloud config get-value project")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    user_email, _, _ = run_cmd("gcloud config get-value account")
    print(f"[*] User Email: {user_email}")

    project_number, _, _ = run_cmd(f"gcloud projects describe {project_id} --format='value(projectNumber)'")
    print(f"[*] Project Number: {project_number}")

    service_account = f"{project_number}-compute@developer.gserviceaccount.com"
    mcp_url = f"https://vibe-zoo-mcp-server-{project_number}.us-central1.run.app/mcp/"

    home_dir = os.path.expanduser("~")

    # =========================================================================
    # TASK 1 & 2: Environment & IAM Setup
    # =========================================================================
    print("\n[Step 1] Ensuring .env file and IAM permissions...")
    zoo_dir = os.path.join(home_dir, "zoo_guide_agent")
    os.makedirs(zoo_dir, exist_ok=True)

    env_content = f"""MODEL="gemini-3.5-flash"
SERVICE_ACCOUNT="{service_account}"
MCP_SERVER_URL="{mcp_url}"
GOOGLE_GENAI_USE_ENTERPRISE=1
GOOGLE_CLOUD_PROJECT={project_id}
PROJECT_NUMBER={project_number}
GOOGLE_CLOUD_LOCATION=us-central1
"""
    with open(os.path.join(zoo_dir, ".env"), "w", encoding="utf-8") as f:
        f.write(env_content)

    apis = [
        "agentplatform.googleapis.com",
        "artifactregistry.googleapis.com",
        "compute.googleapis.com",
        "cloudbuild.googleapis.com",
        "run.googleapis.com"
    ]
    run_cmd(f"gcloud services enable {' '.join(apis)} --quiet")

    run_cmd(f"gcloud projects add-iam-policy-binding {project_id} --member='user:{user_email}' --role='roles/run.admin' --quiet")
    run_cmd(f"gcloud projects add-iam-policy-binding {project_id} --member='user:{user_email}' --role='roles/agentplatform.user' --quiet")

    # =========================================================================
    # TASK 3: Fix & Deploy MCP Server
    # =========================================================================
    print("\n[Step 2] Fixing server.py in mcp-on-cloudrun...")
    mcp_dir = os.path.join(home_dir, "mcp-on-cloudrun")
    server_py_path = os.path.join(mcp_dir, "server.py")

    if os.path.exists(server_py_path):
        with open(server_py_path, "r", encoding="utf-8") as f:
            code = f.read()

        # Fix 1: Uncomment `mcp = FastMCP(...)`
        code = re.sub(r"#\s*mcp\s*=\s*FastMCP", "mcp = FastMCP", code)

        # Fix 2: Ensure decorators like `@mcp.tool` or `@mcp.prompt` are uncommented
        code = re.sub(r"#\s*@mcp\.", "@mcp.", code)

        # Fix 3: Ensure transport and host/port setup in main
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
        print("Patched server.py successfully!")

    print("\nTesting MCP server locally with uv run local_mcp_call.py...")
    os.chdir(mcp_dir)
    # Start server in background for local call test
    server_proc = subprocess.Popen(["uv", "run", "server.py"], cwd=mcp_dir)
    import time
    time.sleep(5)

    # Run local_mcp_call.py
    run_cmd(f"gcloud config set project {project_id}")
    stdout, stderr, ret = run_cmd("uv run local_mcp_call.py")
    print(f"local_mcp_call.py output:\n{stdout}")

    # Terminate background server process
    server_proc.terminate()
    try:
        server_proc.wait(timeout=2)
    except:
        server_proc.kill()

    print("\nDeploying vibe-zoo-mcp-server to Cloud Run...")
    run_cmd(f"""gcloud run deploy vibe-zoo-mcp-server \
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
    print("\n[Step 3] Configuring ~/.gemini/settings.json...")
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

    # Trigger Cloud Run log entry read
    run_cmd(f"gcloud run services logs read vibe-zoo-mcp-server --region us-central1 --limit=5 --project={project_id}")

    # =========================================================================
    # TASK 5: Update & Deploy ADK Agent to Cloud Run
    # =========================================================================
    print("\n[Step 4] Fixing zoo_guide_agent/agent.py...")
    agent_py_path = os.path.join(zoo_dir, "agent.py")

    if os.path.exists(agent_py_path):
        with open(agent_py_path, "r", encoding="utf-8") as f:
            acode = f.read()

        # Uncomment any commented tool lines or MCP imports
        acode = re.sub(r"#\s*(from\s+.*?import.*?)", r"\1", acode)
        acode = re.sub(r"#\s*(import\s+.*?)", r"\1", acode)
        acode = re.sub(r"#\s*(tools\s*=)", r"\1", acode)
        acode = re.sub(r"#\s*(MCPToolset)", r"\1", acode)

        # Make sure google_search is in tools
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
        print("Patched zoo_guide_agent/agent.py successfully!")

    print("\nTesting ADK Agent locally...")
    os.chdir(zoo_dir)
    export_path = 'export PATH=$PATH:"/home/${USER}/.local/bin"'

    print("Deploying vibe-zoo-tour-guide to Cloud Run...")
    run_cmd(f"""{export_path} && adk deploy cloud_run \
        --project={project_id} \
        --region=us-central1 \
        --service_name=vibe-zoo-tour-guide \
        --with_ui \
        . \
        -- \
        --labels=lab-dev=cloud-zoo-run-adk-service \
        --quiet""")

    print("\n======================================================================")
    print("  GSP532 COMPLETE SOLVER FINISHED!")
    print("======================================================================")

if __name__ == "__main__":
    main()
