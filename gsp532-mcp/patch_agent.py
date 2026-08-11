import os

agent_path = os.path.expanduser("~/zoo_guide_agent/agent.py")

agent_code = """import os
import logging
from dotenv import load_dotenv

from google.adk.agents import Agent
from google.adk.tools import google_search

load_dotenv()

logging.basicConfig(level=logging.INFO)

root_agent = Agent(
    name="zoo_guide_agent",
    model=os.getenv("MODEL", "gemini-3.5-flash"),
    description="Zoo guide agent that answers visitor queries.",
    instructions="You are a helpful zoo tour guide AI agent. Use Google Search and MCP tools to answer visitor questions.",
    tools=[google_search],
)
"""

os.makedirs(os.path.dirname(agent_path), exist_ok=True)
with open(agent_path, "w", encoding="utf-8") as f:
    f.write(agent_code)

print("Successfully wrote complete agent.py!")
