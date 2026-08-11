#!/usr/bin/env python3
"""
GSP532 - Session solver for THIS lab session.
Hardcoded session values (from the lab page):
  Project:        qwiklabs-gcp-02-b3ae68ebdff9
  Project number: 782897773953
  Username:       student-04-8cd0c6aaad74@qwiklabs.net
  MCP service:    vibe-co-zoo-mcp-server   (URL .../mcp/)
  ADK service:    vibe-co-zoo-tour-guide
"""

import os
import re
import sys
import json
import subprocess
import time

PROJECT_ID = "qwiklabs-gcp-02-b3ae68ebdff9"
PROJECT_NUMBER = "782897773953"
USER_EMAIL = "student-04-8cd0c6aaad74@qwiklabs.net"
MCP_SERVICE = "vibe-co-zoo-mcp-server"
ADK_SERVICE = "vibe-co-zoo-tour-guide"
REGION = "us-central1"
COMPUTE_SA = f"{PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
CLOUDBUILD_SA = f"{PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
MCP_URL = f"https://{MCP_SERVICE}-{PROJECT_NUMBER}.{REGION}.run.app/mcp/"


def run_cmd(cmd, check=False, timeout=1200):
    print(f"  > {cmd}")
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
    if res.returncode != 0 and check:
        print(f"    Error ({res.returncode}): {res.stderr.strip()[:500]}")
    if res.stdout.strip():
        print(f"    {res.stdout.strip()[:600]}")
    return res.stdout.strip(), res.stderr.strip(), res.returncode


def main():
    home = os.path.expanduser("~")

    print("=" * 70)
    print(f"  GSP532 SESSION SOLVER  |  {PROJECT_ID}")
    print("=" * 70)

    # ---------------- Task 1: env + APIs ----------------
    print("\n[Task 1] Environment + enable APIs...")
    run_cmd(f"gcloud config set project {PROJECT_ID} --quiet", timeout=60)

    zoo_dir = os.path.join(home, "zoo_guide_agent")
    os.makedirs(zoo_dir, exist_ok=True)
    env_content = f"""MODEL="gemini-3.5-flash"
SERVICE_ACCOUNT="{COMPUTE_SA}"
MCP_SERVER_URL="{MCP_URL}"
GOOGLE_GENAI_USE_ENTERPRISE=1
GOOGLE_CLOUD_PROJECT={PROJECT_ID}
PROJECT_NUMBER={PROJECT_NUMBER}
GOOGLE_CLOUD_LOCATION={REGION}
"""
    with open(os.path.join(zoo_dir, ".env"), "w", encoding="utf-8") as f:
        f.write(env_content)
    print("  .env written")

    apis = [
        "agentplatform.googleapis.com",
        "artifactregistry.googleapis.com",
        "compute.googleapis.com",
        "cloudbuild.googleapis.com",
        "run.googleapis.com",
    ]
    run_cmd(f"gcloud services enable {' '.join(apis)} --quiet", check=False, timeout=600)

    # ---------------- Task 2: IAM bindings ----------------
    print("\n[Task 2] IAM policy bindings...")
    for role in ["roles/run.admin", "roles/agentplatform.user", "roles/iam.serviceAccountUser"]:
        run_cmd(f"gcloud projects add-iam-policy-binding {PROJECT_ID} --member='user:{USER_EMAIL}' --role='{role}' --quiet", check=False, timeout=300)
    for role in ["roles/run.admin", "roles/run.invoker", "roles/agentplatform.user", "roles/storage.objectViewer"]:
        run_cmd(f"gcloud projects add-iam-policy-binding {PROJECT_ID} --member='serviceAccount:{COMPUTE_SA}' --role='{role}' --quiet", check=False, timeout=300)
    for role in ["roles/run.admin", "roles/iam.serviceAccountUser"]:
        run_cmd(f"gcloud projects add-iam-policy-binding {PROJECT_ID} --member='serviceAccount:{CLOUDBUILD_SA}' --role='{role}' --quiet", check=False, timeout=300)
    print("  [OK] IAM bindings applied")

    # ---------------- Task 3: Fix + test MCP server ----------------
    print("\n[Task 3] Fix MCP server + local test...")
    mcp_dir = os.path.join(home, "mcp-on-cloudrun")
    server_py = os.path.join(mcp_dir, "server.py")

    if os.path.exists(server_py):
        code = open(server_py, encoding="utf-8").read()

        # Un-comment the FastMCP object and tools
        code = re.sub(r"#\s*mcp\s*=\s*FastMCP", "mcp = FastMCP", code)
        code = re.sub(r"#\s*@mcp\.", "@mcp.", code)
        # Remove any stray commented mcp.run
        code = re.sub(r"#\s*mcp\.run\(.*?\)", "", code)

        # Make sure the server can start: local run via SSE on 8080
        if "mcp.run(" not in code:
            code += """

if __name__ == "__main__":
    import os
    port = int(os.environ.get("PORT", 8080))
    mcp.run(transport="sse", host="0.0.0.0", port=port)
"""
        open(server_py, "w", encoding="utf-8").write(code)
        print("  server.py patched")

    # local test: start server, wait, then run local_mcp_call.py
    os.chdir(mcp_dir)
    proc = subprocess.Popen(["uv", "run", "server.py"], cwd=mcp_dir,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(6)
    run_cmd(f"gcloud config set project {PROJECT_ID} --quiet", timeout=60)
    out, err, ret = run_cmd("uv run local_mcp_call.py", timeout=300)
    if out:
        print("  local_mcp_call output present (walrus data expected).")
    proc.terminate()
    try:
        proc.wait(timeout=2)
    except Exception:
        proc.kill()

    # deploy to Cloud Run (no unauthenticated)
    print("\n[Task 3 cont.] Deploy MCP server to Cloud Run...")
    run_cmd(f"gcloud run deploy {MCP_SERVICE} --no-allow-unauthenticated --region={REGION} --source=. --min=1 --project={PROJECT_ID} --labels=lab-dev=mcp-zoo-cloud-run-service --quiet", check=False, timeout=1800)

    # ---------------- Task 4: Gemini settings + agent ----------------
    print("\n[Task 4] Configure Gemini settings...")
    id_token, _, _ = run_cmd("gcloud auth print-identity-token", timeout=60)
    gemini_dir = os.path.join(home, ".gemini")
    os.makedirs(gemini_dir, exist_ok=True)
    settings = {
        "mcpServers": {
            "zoo-remote": {
                "httpUrl": MCP_URL,
                "headers": {"Authorization": f"Bearer {id_token}"},
            }
        },
        "selectedAuthType": "compute-default-credentials",
        "hasSeenIdeIntegrationNudge": True,
    }
    with open(os.path.join(gemini_dir, "settings.json"), "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2)
    print("  settings.json written")

    # Patch agent.py (un-comment tools and add google_search)
    agent_py = os.path.join(zoo_dir, "agent.py")
    if os.path.exists(agent_py):
        acode = open(agent_py, encoding="utf-8").read()
        acode = re.sub(r"#\s*(from\s+.*?import.*)", r"\1", acode)
        acode = re.sub(r"#\s*(import\s+\w+)", r"\1", acode)
        acode = re.sub(r"#\s*(tools\s*=)", r"\1", acode)
        if "google_search" not in acode:
            acode = "from google.adk.tools import google_search\n" + acode
        open(agent_py, "w", encoding="utf-8").write(acode)
        print("  agent.py patched")

    # Verify server logs show tool call
    run_cmd(f"gcloud run services logs read {MCP_SERVICE} --region {REGION} --limit=5 --project={PROJECT_ID}", check=False, timeout=120)

    # ---------------- Task 5: Dockerize + deploy ADK to Cloud Run ----------------
    print("\n[Task 5] Deploy ADK agent to Cloud Run...")
    os.chdir(zoo_dir)
    run_cmd("python -m venv .venv", timeout=180)
    run_cmd('source .venv/bin/activate && pip install --no-cache-dir -r requirements.txt', timeout=1800)
    run_cmd(f"""source .venv/bin/activate && export PATH=$PATH:"$HOME/.local/bin" && export PROJECT_NUMBER={PROJECT_NUMBER} && export ID_TOKEN=$(gcloud auth print-identity-token) && export GOOGLE_CLOUD_PROJECT={PROJECT_ID} && adk deploy cloud_run --project={PROJECT_ID} --region={REGION} --service_name={ADK_SERVICE} --with_ui . -- --labels=lab-dev=cloud-zoo-run-adk-service --quiet""", check=False, timeout=2400)

    print("\n" + "=" * 70)
    print("  GSP532 SESSION SOLVER FINISHED")
    print("  Manual checks remaining (console/browser):")
    print("   - Task 4: non-interactive Gemini CLI MCP conversation (optional check)")
    print(f"   - Task 5: ADK UI at https://{ADK_SERVICE}-{PROJECT_NUMBER}.{REGION}.run.app/ ,")
    print("     toggle Token Streaming ON, ask 'Where can I find elephants?'")
    print("=" * 70)


if __name__ == "__main__":
    main()