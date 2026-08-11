import os
import subprocess

agent_path = os.path.expanduser("~/zoo_guide_agent/agent.py")

agent_code = """import os
import subprocess
import logging
from dotenv import load_dotenv

from google.adk.agents import Agent
from google.adk.tools import google_search
from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset, StreamableHTTPConnectionParams

load_dotenv()

logging.basicConfig(level=logging.INFO)

def get_id_token():
    token = os.getenv("ID_TOKEN")
    if not token:
        try:
            token = subprocess.check_output(["gcloud", "auth", "print-identity-token"], text=True).strip()
        except Exception:
            token = ""
    return token

id_token = get_id_token()
mcp_url = os.getenv("MCP_SERVER_URL")

headers = {}
if id_token:
    headers["Authorization"] = f"Bearer {id_token}"

try:
    mcp_toolset = MCPToolset(
        connection_params=StreamableHTTPConnectionParams(
            url=mcp_url,
            headers=headers
        )
    )
    agent_tools = [google_search, mcp_toolset]
except Exception as e:
    logging.warning(f"MCPToolset connection warning: {e}")
    agent_tools = [google_search]

root_agent = Agent(
    name="zoo_guide_agent",
    model=os.getenv("MODEL", "gemini-3.5-flash"),
    description="Zoo guide agent that answers visitor queries using Google Search and remote MCP server.",
    instructions="You are a helpful zoo tour guide AI agent. Use Google Search and remote MCP tools to answer visitor questions.",
    tools=agent_tools,
)
"""

os.makedirs(os.path.dirname(agent_path), exist_ok=True)
with open(agent_path, "w", encoding="utf-8") as f:
    f.write(agent_code)

print("Successfully updated agent.py with ID_TOKEN Bearer Auth headers for MCPToolset!")
