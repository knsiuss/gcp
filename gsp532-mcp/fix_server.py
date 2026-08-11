#!/usr/bin/env python3
import os
import re

server_path = os.path.expanduser("~/mcp-on-cloudrun/server.py")
if os.path.exists(server_path):
    with open(server_path, "r", encoding="utf-8") as f:
        code = f.read()

    # Uncomment any commented mcp = FastMCP(...) lines
    code = re.sub(r"#\s*mcp\s*=\s*", "mcp = ", code)
    code = re.sub(r"#\s*@mcp", "@mcp", code)

    # Make sure mcp = FastMCP(...) exists before any @mcp decorator
    if "mcp = FastMCP" not in code:
        code = re.sub(
            r"(from\s+fastmcp\s+import\s+FastMCP)",
            r"\1\n\nmcp = FastMCP('Zoo Animal Data MCP Server 🦁🐧🐻')",
            code
        )

    # Ensure main execution block exists
    if 'if __name__ == "__main__":' not in code:
        code += """

if __name__ == "__main__":
    import os
    port = int(os.environ.get("PORT", 8080))
    mcp.run(transport="sse", host="0.0.0.0", port=port)
"""

    with open(server_path, "w", encoding="utf-8") as f:
        f.write(code)
    print("Successfully patched server.py with valid FastMCP instance!")
