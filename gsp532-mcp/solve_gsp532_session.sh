#!/bin/bash
# ============================================================================
# GSP532 session solver (THIS session) - drives solve_gsp532_session.py
#
# Session values: project qwiklabs-gcp-02-b3ae68ebdff9 (num 782897773953)
# MCP service vibe-co-zoo-mcp-server, ADK service vibe-co-zoo-tour-guide
#
# Usage (in Cloud Shell, AFTER cloning the repo):
#   git clone https://github.com/knsiuss/gcp.git gcp-labs
#   cd gcp-labs/gsp532-mcp
#   chmod +x solve_gsp532_session.sh
#   ./solve_gsp532_session.sh
# ============================================================================
set -e

# The lab zips the code into ~/zoo_guide_agent and ~/mcp-on-cloudrun.
# Make sure lab code is present first, otherwise fetch it here.
if [ ! -d "$HOME/zoo_guide_agent" ] || [ ! -d "$HOME/mcp-on-cloudrun" ]; then
  echo "[*] Downloading lab boilerplate code..."
  gcloud storage cp gs://qwiklabs-gcp-02-b3ae68ebdff9-labconfig-bucket/labs_code.zip . 2>/dev/null || true
  unzip -o labs_code.zip 2>/dev/null || true
fi

# Install deps used by the python solver
pip install -q google-adk uv 2>/dev/null || true

python3 "$HOME/gcp-labs/gsp532-mcp/solve_gsp532_session.py" \
  || python3 solve_gsp532_session.py