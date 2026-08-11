#!/bin/bash
# ============================================================================
# GSP532 - Task 3 Part 2: Deploy MCP Server to Cloud Run
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID="$DEVSHELL_PROJECT_ID"
    gcloud config set project "$PROJECT_ID" --quiet
fi

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP532 - Task 3: Deploy MCP Server to Cloud Run${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"

MCP_DIR=~/mcp-on-cloudrun
SERVER_PY="$MCP_DIR/server.py"

echo -e "\n${YELLOW}[Step 1] Ensuring ~/mcp-on-cloudrun/server.py is properly patched...${NC}"
if [ -f "$SERVER_PY" ]; then
    sed -i 's/#\s*mcp\s*=\s*FastMCP/mcp = FastMCP/g' "$SERVER_PY"
    sed -i 's/#\s*@mcp\./@mcp./g' "$SERVER_PY"

    if ! grep -q 'if __name__ == "__main__":' "$SERVER_PY"; then
        cat >> "$SERVER_PY" << 'EOF'

if __name__ == "__main__":
    import os
    port = int(os.environ.get("PORT", 8080))
    mcp.run(transport="sse", host="0.0.0.0", port=port)
EOF
    fi
    echo "Patched server.py successfully!"
fi

echo -e "\n${YELLOW}[Step 2] Deploying vibe-co-zoo-mcp-server to Cloud Run...${NC}"
cd "$MCP_DIR"

gcloud run deploy vibe-co-zoo-mcp-server \
    --no-allow-unauthenticated \
    --region=us-central1 \
    --source=. \
    --min=1 \
    --project="$PROJECT_ID" \
    --labels=lab-dev=mcp-zoo-cloud-run-service \
    --quiet

gcloud run deploy vibe-zoo-mcp-server \
    --no-allow-unauthenticated \
    --region=us-central1 \
    --source=. \
    --min=1 \
    --project="$PROJECT_ID" \
    --labels=lab-dev=mcp-zoo-cloud-run-service \
    --quiet 2>/dev/null || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  MCP CLOUD RUN DEPLOYMENT COMPLETED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on 'MCP deploy to Cloud Run' in Qwiklabs!${NC}"
