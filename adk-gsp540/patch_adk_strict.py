#!/usr/bin/env python3
"""
GSP540 - ADK Challenge Lab Strict Patcher & Verifier
"""

import os
import re
import sys
import subprocess

def main():
    project_id = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("GOOGLE_CLOUD_PROJECT", "")
    print(f"[*] Strict Patching ADK Project for Project ID: {project_id}")

    base_dir = os.path.expanduser("~/adk_project")

    # 1. Ensure .env files in all dirs
    env_content = f"""GOOGLE_GENAI_USE_ENTERPRISE=true
GOOGLE_CLOUD_PROJECT={project_id}
GOOGLE_CLOUD_LOCATION=global
MODEL=gemini-3.5-flash
"""

    dirs = ["", "my_google_search_agent", "geo_validator", "llm_auditor"]
    for d in dirs:
        target_dir = os.path.join(base_dir, d) if d else base_dir
        os.makedirs(target_dir, exist_ok=True)
        with open(os.path.join(target_dir, ".env"), "w", encoding="utf-8") as f:
            f.write(env_content)

    # 2. Patch my_google_search_agent/agent.py
    search_file = os.path.join(base_dir, "my_google_search_agent/agent.py")
    if os.path.exists(search_file):
        with open(search_file, "r", encoding="utf-8") as f:
            content = f.read()

        # Add google_search import if missing
        if "google_search" not in content:
            content = "from google.adk.tools import google_search\n" + content

        # Replace tools=[] or tools=None or add tools=[google_search]
        if "tools=[" in content:
            content = re.sub(r"tools=\s*\[.*?\]", "tools=[google_search]", content)
        elif "tools=None" in content:
            content = content.replace("tools=None", "tools=[google_search]")
        else:
            content = re.sub(r"(Agent\s*\([^)]*)(\))", r"\1, tools=[google_search]\2", content)

        with open(search_file, "w", encoding="utf-8") as f:
            f.write(content)
        print("  [+] Patched my_google_search_agent/agent.py")

    # 3. Patch geo_validator/agent.py
    geo_file = os.path.join(base_dir, "geo_validator/agent.py")
    if os.path.exists(geo_file):
        with open(geo_file, "r", encoding="utf-8") as f:
            content = f.read()

        # Ensure BaseModel and CountryCapital class
        if "class CountryCapital" not in content:
            pydantic_code = "from pydantic import BaseModel\n\nclass CountryCapital(BaseModel):\n    capital: str\n\n"
            content = pydantic_code + content

        # Ensure model="gemini-3.5-flash"
        content = re.sub(r'model\s*=\s*["\'].*?["\']', 'model="gemini-3.5-flash"', content)

        # Set output_schema=CountryCapital, disallow_transfer_to_parent=True, disallow_transfer_to_peers=True
        if "output_schema" not in content:
            content = re.sub(
                r"(Agent\s*\([^)]*)(\))",
                r"\1, output_schema=CountryCapital, disallow_transfer_to_parent=True, disallow_transfer_to_peers=True\2",
                content
            )
        else:
            content = re.sub(r"output_schema\s*=\s*.*?,", "output_schema=CountryCapital,", content)

        with open(geo_file, "w", encoding="utf-8") as f:
            f.write(content)
        print("  [+] Patched geo_validator/agent.py")

    # 4. Patch llm_auditor/agent.py
    auditor_file = os.path.join(base_dir, "llm_auditor/agent.py")
    if os.path.exists(auditor_file):
        with open(auditor_file, "r", encoding="utf-8") as f:
            content = f.read()

        # Uncomment reviser import
        content = re.sub(r"#\s*(from\s+.*?reviser.*?import\s+reviser_agent)", r"\1", content)
        content = re.sub(r"#\s*(import\s+reviser_agent)", r"\1", content)

        # Add reviser_agent to sub_agents list
        if "sub_agents" in content:
            if "reviser_agent" not in content.split("sub_agents")[1]:
                content = re.sub(
                    r"sub_agents\s*=\s*\[(.*?)\]",
                    r"sub_agents=[\1, reviser_agent]",
                    content,
                    flags=re.DOTALL
                )

        with open(auditor_file, "w", encoding="utf-8") as f:
            f.write(content)
        print("  [+] Patched llm_auditor/agent.py")

if __name__ == "__main__":
    main()
