#!/usr/bin/env python3
"""
GSP540 - ADK Challenge Lab Inspector and Fixer
"""

import os
import sys

def print_file(path):
    print(f"\n==================== {path} ====================")
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            print(f.read())
    else:
        print("FILE NOT FOUND!")

def main():
    base_dir = os.path.expanduser("~/adk_project")
    print_file(os.path.join(base_dir, "my_google_search_agent/agent.py"))
    print_file(os.path.join(base_dir, "geo_validator/agent.py"))
    print_file(os.path.join(base_dir, "llm_auditor/agent.py"))

if __name__ == "__main__":
    main()
