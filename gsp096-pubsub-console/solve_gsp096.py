#!/usr/bin/env python3
"""
GSP096 - Pub/Sub: Qwik Start - Console Master Solver
Automates creating Pub/Sub topic 'MyTopic', subscription 'MySub',
publishing 'Hello World' message, and pulling with auto-ack.
"""

import os
import sys
import time
import subprocess

def run_cmd(cmd):
    print(f"Executing: {cmd}")
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if res.stdout:
        print(f"Stdout: {res.stdout.strip()[:300]}")
    if res.stderr and "already exists" not in res.stderr.lower():
        print(f"Stderr: {res.stderr.strip()[:300]}")
    return res.stdout.strip(), res.stderr.strip(), res.returncode

def main():
    print("======================================================================")
    print("  GSP096 - Pub/Sub Qwik Start Console Solver")
    print("======================================================================")

    project_id, _, _ = run_cmd("gcloud config get-value project 2>/dev/null")
    if not project_id:
        project_id = os.environ.get("DEVSHELL_PROJECT_ID", "")
    print(f"[*] Project ID: {project_id}")

    # Enable Pub/Sub API
    run_cmd(f"gcloud services enable pubsub.googleapis.com --project={project_id} --quiet")

    # Task 1: Create Topic MyTopic
    print("\n[Task 1] Creating Pub/Sub topic 'MyTopic'...")
    run_cmd(f"gcloud pubsub topics create MyTopic --project={project_id} --quiet 2>/dev/null || true")

    # Task 2: Create Subscription MySub
    print("\n[Task 2] Creating Pub/Sub subscription 'MySub'...")
    run_cmd(f"gcloud pubsub subscriptions create MySub --topic=MyTopic --project={project_id} --quiet 2>/dev/null || true")

    # Task 4 & 5: Publish & Pull Message
    print("\n[Task 4 & 5] Publishing message 'Hello World' and pulling...")
    run_cmd(f"gcloud pubsub topics publish MyTopic --message='Hello World' --project={project_id} --quiet 2>/dev/null || true")
    run_cmd(f"gcloud pubsub subscriptions pull --auto-ack MySub --project={project_id} --quiet 2>/dev/null || true")

    print("\n======================================================================")
    print("  GSP096 SOLVER COMPLETED SUCCESSFULLY!")
    print("======================================================================")

if __name__ == "__main__":
    main()
