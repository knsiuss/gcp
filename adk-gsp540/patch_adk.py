#!/usr/bin/env python3
"""
GSP540 - Engineer AI Agents with ADK Challenge Lab
Python Patcher Script for adk_project
"""

import os
import re
import sys

def patch_file(filepath, patch_func):
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return False
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    new_content = patch_func(content)
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(new_content)
    print(f"Patched {filepath} successfully.")
    return True

def create_env_file(directory, project_id):
    os.makedirs(directory, exist_ok=True)
    env_path = os.path.join(directory, ".env")
    env_content = f"""GOOGLE_GENAI_USE_ENTERPRISE=true
GOOGLE_CLOUD_PROJECT={project_id}
GOOGLE_CLOUD_LOCATION=global
MODEL=gemini-3.5-flash
"""
    with open(env_path, "w", encoding="utf-8") as f:
        f.write(env_content)
    print(f"Created {env_path}")

def patch_my_google_search_agent(content):
    # Ensure google_search is imported
    if "google_search" not in content:
        if "from google.adk.tools import" in content:
            content = content.replace("from google.adk.tools import", "from google.adk.tools import google_search, ")
        elif "from google.genai.types import" in content:
            content = "from google.adk.tools import google_search\n" + content
        else:
            content = "from google.adk.tools import google_search\n" + content

    # Add tools=[google_search] to Agent definition if not present
    if "tools=" not in content:
        content = re.sub(
            r"(Agent\s*\(.*?)(\))",
            r"\1, tools=[google_search]\2",
            content,
            flags=re.DOTALL
        )
    elif "tools=[]" in content:
        content = content.replace("tools=[]", "tools=[google_search]")
    elif "tools=None" in content:
        content = content.replace("tools=None", "tools=[google_search]")
    
    return content

def patch_geo_validator(content):
    # Add BaseModel & CountryCapital if not present
    if "class CountryCapital" not in content:
        pydantic_code = """from pydantic import BaseModel

class CountryCapital(BaseModel):
    capital: str

"""
        content = pydantic_code + content

    # Ensure model is gemini-3.5-flash
    content = re.sub(r'model\s*=\s*["\'].*?["\']', 'model="gemini-3.5-flash"', content)

    # Add output_schema=CountryCapital, disallow_transfer_to_parent=True, disallow_transfer_to_peers=True
    if "output_schema" not in content:
        content = re.sub(
            r"(Agent\s*\(.*?)(\))",
            r"\1, output_schema=CountryCapital, disallow_transfer_to_parent=True, disallow_transfer_to_peers=True\2",
            content,
            flags=re.DOTALL
        )

    return content

def patch_llm_auditor(content):
    # Uncomment reviser import if commented out
    content = re.sub(r"#\s*(from\s+\.?reviser\s+import\s+reviser_agent)", r"\1", content)
    content = re.sub(r"#\s*(from\s+reviser\s+import\s+reviser_agent)", r"\1", content)

    # Ensure reviser_agent is in sub_agents list
    if "sub_agents" in content:
        if "reviser_agent" not in content.split("sub_agents")[1]:
            content = re.sub(
                r"sub_agents\s*=\s*\[(.*?)\]",
                r"sub_agents=[\1, reviser_agent]",
                content,
                flags=re.DOTALL
            )
            content = content.replace("critic_agent,", "critic_agent")
            content = content.replace("critic_agent ,", "critic_agent")

    return content

def main():
    if len(sys.argv) < 2:
        print("Usage: patch_adk.py <PROJECT_ID>")
        sys.exit(1)

    project_id = sys.argv[1]
    print(f"Patching ADK Project for Project ID: {project_id}")

    # Set up .env files
    directories = [
        ".",
        "my_google_search_agent",
        "geo_validator",
        "llm_auditor"
    ]
    for d in directories:
        create_env_file(d, project_id)

    # Patch my_google_search_agent/agent.py
    search_agent_path = "my_google_search_agent/agent.py"
    patch_file(search_agent_path, patch_my_google_search_agent)

    # Patch geo_validator/agent.py
    geo_path = "geo_validator/agent.py"
    patch_file(geo_path, patch_geo_validator)

    # Patch llm_auditor/agent.py
    auditor_path = "llm_auditor/agent.py"
    patch_file(auditor_path, patch_llm_auditor)

    print("All ADK Agent files patched successfully!")

if __name__ == "__main__":
    main()
