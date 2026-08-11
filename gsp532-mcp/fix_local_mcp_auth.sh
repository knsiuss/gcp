#!/bin/bash
# ============================================================================
# GSP532 - Fix local ADK web 403 on MCP server
#
# Symptoms: ADK web loads zoo_guide_agent but no output / exception
# "HTTP Request: POST ...vibe-co-zoo-mcp-server.../mcp/ HTTP/1.1 403 Forbidden"
#
# Cause: MCP Cloud Run service is --no-allow-unauthenticated, so every MCP
# request needs `Authorization: Bearer $ID_TOKEN`. agent.py does not attach it.
#
# Fix: patch agent.py to fetch a fresh ID token and pass it as a header so
# the local ADK web session can call the MCP server (same as Gemini CLI).
#
# Usage (Cloud Shell):
#   bash $HOME/gcp-labs/gsp532-mcp/fix_local_mcp_auth.sh
# ============================================================================
set -e

PROJECT_ID="qwiklabs-gcp-02-b3ae68ebdff9"
REGION="us-central1"

cd ~/zoo_guide_agent
source .venv/bin/activate

python3 - "$PWD/agent.py" <<'PYEOF'
import sys, os
import io
p = os.path.expanduser(sys.argv[1])
s = open(p, encoding="utf-8").read()

marker = "__get_mcp_id_token__"
if marker in s:
    print("  already patched")
else:
    helper = '''

import subprocess

def __get_mcp_id_token__():
    try:
        return subprocess.check_output(
            ["gcloud", "auth", "print-identity-token"], text=True
        ).strip()
    except Exception as e:
        print("[warn] could not get ID token:", e)
        return ""

'''
    # insert helper right after the imports block (after load_dotenv line if present)
    if "__get_mcp_id_token__" not in s:
        if "load_dotenv()" in s:
            s = s.replace("load_dotenv()", "load_dotenv()\n" + helper, 1)
        else:
            s = helper + s

    # add headers to the MCP connection params
    if "StreamableHTTPConnectionParams(" in s and "headers=" not in s:
        s = s.replace(
            "StreamableHTTPConnectionParams(\n            url=mcp_url,\n        )",
            "StreamableHTTPConnectionParams(\n            url=mcp_url,\n            headers={\"Authorization\": f\"Bearer {__get_mcp_id_token__()}\"},\n        )",
        )
    # fallback single-line pattern
    if "headers=" not in s and "StreamableHTTPConnectionParams(" in s:
        s = s.replace(
            "StreamableHTTPConnectionParams(url=mcp_url)",
            'StreamableHTTPConnectionParams(url=mcp_url, headers={"Authorization": f"Bearer {__get_mcp_id_token__()}"})',
        )

open(p, "w", encoding="utf-8").write(s)
print("  patched agent.py (ID token header added)")
PYEOF

echo "  verifying import..."
python3 -c "import agent; print('OK root_agent =', agent.root_agent.name)" 2>&1 | grep -vE 'Warning|UserWarning|deprecated|migrate|import agentplatform|rag'
echo "  verifying MCP call works..."
python3 -c "
import agent, asyncio
from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
app = agent.root_agent.name
ss = InMemorySessionService()
ss.create_session(app_name=app, user_id='u', session_id='s')
runner = Runner(agent=agent.root_agent, app_name=app)
async def go():
    async for ev in runner.run(user_id='u', session_id='s', query='Where can I find penguins?'):
        if ev.is_final_response():
            txt = ev.content.parts[0].text if ev.content.parts else ''
            print('FINAL:', txt)
asyncio.run(go())
" 2>&1 | grep -E 'FINAL|Error|403|tool_call|CallToolResult' | head -10

echo -e "\nIf you see a FINAL answer -> restart adk web and test in the UI:"
echo "  pkill -f \"adk web\"; sleep 2; cd ~ && adk web"