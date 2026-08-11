#!/bin/bash
# ============================================================================
# GSP1145 - Task 3 Inspect & Attach Aspects
# ============================================================================

set -e

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID="$DEVSHELL_PROJECT_ID"
    gcloud config set project "$PROJECT_ID" --quiet
fi

cp ~/gcp-labs/gsp1145-aspects/inspect_entry.py . 2>/dev/null || true
python3 inspect_entry.py || python3 ~/gcp-labs/gsp1145-aspects/inspect_entry.py
