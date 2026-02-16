#!/bin/bash
# Test script to verify Godot MCP connection

echo "=== Testing Godot MCP Setup ==="
echo

# Check if Godot is listening on port 9080
echo "1. Checking if Godot WebSocket is running on port 9080..."
if netstat -an | grep -q ":9080.*LISTENING"; then
    echo "   ✓ Godot WebSocket server is running"
else
    echo "   ✗ Godot WebSocket server not detected"
    echo "   → Make sure Godot is open with the MCP plugin enabled"
fi
echo

# Check if Node.js is available
echo "2. Checking Node.js installation..."
if command -v node &> /dev/null; then
    echo "   ✓ Node.js found: $(node --version)"
else
    echo "   ✗ Node.js not found"
    exit 1
fi
echo

# Check if MCP server files exist
echo "3. Checking MCP server files..."
if [ -f ".mcp/godot-mcp-server/dist/index.js" ]; then
    echo "   ✓ MCP server built"
else
    echo "   ✗ MCP server not built"
    echo "   → Run: cd .mcp/godot-mcp-server && npm run build"
    exit 1
fi
echo

# Check MCP configuration
echo "4. Checking MCP configuration..."
if [ -f ".claude/mcp.json" ]; then
    echo "   ✓ MCP config exists"
    echo "   Configuration:"
    cat .claude/mcp.json | grep -A 10 "godot-mcp"
else
    echo "   ✗ MCP config not found"
    exit 1
fi
echo

echo "=== Setup Complete ==="
echo
echo "Next steps:"
echo "1. Make sure Godot is running with the MCP plugin enabled"
echo "2. Restart Claude Code to load the MCP server"
echo "3. Try commands like: 'Show me the current scene tree'"
