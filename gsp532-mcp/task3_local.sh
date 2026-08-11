#!/bin/bash
# ============================================================================
# GSP532 - Task 3 Local Test: Fix server.py and Run local_mcp_call.py
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
echo -e "${BOLD}  GSP532 - Task 3: Fix & Test MCP Server Locally${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"

MCP_DIR=~/mcp-on-cloudrun
SERVER_PY="$MCP_DIR/server.py"

echo -e "\n${YELLOW}[Step 1] Fixing ~/mcp-on-cloudrun/server.py...${NC}"
if [ -f "$SERVER_PY" ]; then
    # Uncomment mcp = FastMCP(...) and @mcp. decorators
    sed -i 's/#\s*mcp\s*=\s*FastMCP/mcp = FastMCP/g' "$SERVER_PY"
    sed -i 's/#\s*@mcp\./@mcp./g' "$SERVER_PY"

    # Add mcp.run in main if missing
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

echo -e "\n${YELLOW}[Step 2] Testing local MCP server with uv run local_mcp_call.py...${NC}"
cd "$MCP_DIR"

# Start background server
uv run server.py &
SERVER_PID=$!
sleep 5

# Set project & run test call
gcloud config set project "$PROJECT_ID" --quiet
uv run local_mcp_call.py || true

# Clean up background process
kill $SERVER_PID 2>/dev/null || true

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  LOCAL MCP TEST COMPLETED!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on 'MCP deploy and test locally' in Qwiklabs!${NC}"
