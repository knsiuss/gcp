import os

agent_path = os.path.expanduser("~/zoo_guide_agent/agent.py")

agent_code = """import os
import logging
from dotenv import load_dotenv

from google.adk.agents import Agent
from google.adk.tools import google_search
from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset, StreamableHTTPConnectionParams

load_dotenv()

logging.basicConfig(level=logging.INFO)

mcp_url = os.getenv("MCP_SERVER_URL")

# Connect to remote MCP toolset if available
try:
    mcp_toolset = MCPToolset(
        connection_params=StreamableHTTPConnectionParams(
            url=mcp_url,
        )
    )
    agent_tools = [google_search, mcp_toolset]
except Exception as e:
    logging.warning(f"MCPToolset connection warning: {e}")
    agent_tools = [google_search]

root_agent = Agent(
    name="zoo_guide_agent",
    model=os.getenv("MODEL", "gemini-3.5-flash"),
    description="Zoo guide agent that answers visitor queries using Wikipedia, Google Search, and remote MCP server.",
    instructions="You are a helpful zoo tour guide AI agent. Use Google Search and remote MCP tools to answer visitor questions.",
    tools=agent_tools,
)
"""

os.makedirs(os.path.dirname(agent_path), exist_ok=True)
with open(agent_path, "w", encoding="utf-8") as f:
    f.write(agent_code)

print("Successfully updated agent.py with MCPToolset and google_search!")
