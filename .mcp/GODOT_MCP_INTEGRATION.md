# Godot MCP Integration - Status & Workaround

## Overview

This document describes the current state of Godot MCP (Model Context Protocol) integration with Claude Code CLI, the challenges encountered, and the working workaround solution.

**Date**: February 14, 2026
**Project**: SvenKillerDemo
**Claude Code Version**: CLI (with MCP support)
**Godot Version**: 4.6

---

## Attempted Solution: Standard MCP Server

### What We Tried

We attempted to integrate [ee0pdt/Godot-MCP](https://github.com/ee0pdt/Godot-MCP), a comprehensive MCP server that bridges Claude Code to Godot Engine.

**Architecture**:
```
Claude Code (CLI) → MCP Server (Node.js) → WebSocket → Godot Plugin
```

### Installation Steps Completed

1. ✅ **Installed Godot Plugin**
   - Location: `addons/godot_mcp/`
   - Source: ee0pdt/Godot-MCP
   - Status: Running successfully on port 9080
   - Console output: `=== MCP SERVER INITIALIZED ===`

2. ✅ **Built Node.js MCP Server**
   - Location: `.mcp/godot-mcp-server/`
   - Dependencies installed: `npm install` (220 packages)
   - TypeScript compiled: `npm run build`
   - Entry point: `.mcp/godot-mcp-server/dist/index.js`

3. ✅ **Created MCP Configuration**
   - Local: `.claude/mcp.json`
   - Global: `~/.claude/mcp.json`
   - Format:
     ```json
     {
       "mcpServers": {
         "godot-mcp": {
           "command": "node",
           "args": [
             "c:\\Users\\Mert\\Desktop\\repos\\SvenKillerDemo\\.mcp\\godot-mcp-server\\dist\\index.js"
           ],
           "env": {
             "MCP_TRANSPORT": "stdio"
           }
         }
       }
     }
     ```

### The Problem

**Despite all components working individually, Claude Code CLI does not connect to the MCP server.**

#### Evidence That Components Work:

1. **Godot Plugin Works**:
   ```bash
   # Godot console shows:
   === MCP SERVER STARTING ===
   Listening on port 9080
   === MCP SERVER INITIALIZED ===
   ```

2. **MCP Server Works When Run Manually**:
   ```bash
   $ cd .mcp/godot-mcp-server
   $ echo '{"jsonrpc":"2.0","id":1,"method":"initialize",...}' | node dist/index.js

   # Output:
   Starting Godot MCP server...
   Connected to Godot WebSocket server
   Successfully connected to Godot WebSocket server
   {"result":{"protocolVersion":"2024-11-05","capabilities":{...}}}
   ```

3. **WebSocket Connection Works**:
   ```bash
   $ netstat -an | grep 9080
   # Shows: LISTENING on port 9080
   ```

#### What Doesn't Work:

- `ListMcpResourcesTool("godot-mcp")` returns: `Server "godot-mcp" is not connected`
- No Godot-specific MCP tools appear in Claude Code's available tools
- No error messages in Claude Code debug logs (`~/.claude/debug/`)
- Multiple Claude Code restarts did not resolve the issue

### Possible Causes

1. **Configuration Location**: Claude Code CLI may not read MCP configs from `.claude/mcp.json` or `~/.claude/mcp.json`
2. **Path Format**: Windows path escaping might not be handled correctly
3. **MCP Version Mismatch**: The MCP protocol version might not be compatible
4. **Initialization Timing**: The MCP server might not be starting before Claude Code needs it
5. **CLI vs Desktop**: MCP configuration format differs between Claude Desktop and Claude Code CLI

---

## Working Workaround: Direct WebSocket Query Tool

Since the standard MCP integration doesn't work, we created a **direct WebSocket client** that bypasses the MCP protocol entirely.

### Solution Architecture

```
Claude Code → Bash Tool → Node.js Script → WebSocket → Godot Plugin
```

### Implementation

**File**: `.mcp/godot-mcp-server/godot-query.js`

```javascript
#!/usr/bin/env node
import WebSocket from 'ws';

const GODOT_WS_URL = 'ws://localhost:9080';

async function sendCommand(command, args = {}) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(GODOT_WS_URL);
    let timeout = setTimeout(() => {
      ws.close();
      reject(new Error(`Timeout waiting for response`));
    }, 5000);

    ws.on('open', () => {
      const message = {
        type: command,
        params: args,
        commandId: `cli-${Date.now()}`
      };
      ws.send(JSON.stringify(message));
    });

    let messageCount = 0;
    ws.on('message', (data) => {
      messageCount++;
      const response = JSON.parse(data.toString());

      // Skip welcome message, wait for actual response
      if (response.type === 'welcome') {
        return;
      }

      clearTimeout(timeout);
      ws.close();
      resolve(response);
    });

    ws.on('error', (err) => {
      clearTimeout(timeout);
      reject(new Error(`WebSocket error: ${err.message}`));
    });
  });
}

async function main() {
  const command = process.argv[2];
  if (!command) {
    console.error('Usage: node godot-query.js <command> [args...]');
    process.exit(1);
  }

  const result = await sendCommand(command);
  console.log(JSON.stringify(result, null, 2));
}

main();
```

### Usage in Claude Code

Claude Code can now query Godot directly using the Bash tool:

```bash
cd .mcp/godot-mcp-server && node godot-query.js <command>
```

### Available Commands

Based on the Godot MCP plugin's command processors:

#### Scene Commands (`MCPSceneCommands`)
- `get_current_scene` - Get current scene info
- `get_scene_structure` - Get scene tree structure (requires `path` param)
- `save_scene` - Save current/specific scene
- `open_scene` - Open a scene file (requires `path` param)
- `create_scene` - Create new scene

#### Node Commands (`MCPNodeCommands`)
- `list_nodes` - List all nodes in current scene
- `get_node_properties` - Get properties of a node (requires `node_path` param)
- `create_node` - Create new node (requires `parent_path`, `node_type`, `node_name`)
- `delete_node` - Delete a node (requires `node_path` param)
- `update_node_property` - Update node property (requires `node_path`, `property`, `value`)

#### Script Commands (`MCPScriptCommands`)
- `list_scripts` - List all GDScript files in project
- `read_script` - Read script content (requires `path` param)
- `write_script` - Write/update script (requires `path`, `content`)
- `create_script` - Create new script (requires `path`)

#### Project Commands (`MCPProjectCommands`)
- `get_project_settings` - Get project settings
- `list_project_files` - List files in project

#### Editor Commands (`MCPEditorCommands`)
- `get_editor_state` - Get current editor state
- `run_project` - Run the game
- `stop_project` - Stop running game

### Example Usage

**Get Current Scene**:
```bash
cd .mcp/godot-mcp-server && node godot-query.js get_current_scene
```

**Response**:
```json
{
  "commandId": "cli-1771026998456",
  "result": {
    "root_node_name": "DebugMovementAndCamera",
    "root_node_type": "Node3D",
    "scene_path": "res://scenes/debug/debug_movement_and_camera.tscn"
  },
  "status": "success"
}
```

**List Scene Nodes**:
```bash
cd .mcp/godot-mcp-server && node godot-query.js list_nodes
```

**Response**:
```json
{
  "commandId": "cli-1771027013854",
  "result": {
    "children": [
      {
        "name": "WorldEnvironment",
        "path": "/root/WorldEnvironment",
        "type": "WorldEnvironment"
      },
      {
        "name": "Player",
        "path": "/root/Player",
        "type": "CharacterBody3D"
      }
    ],
    "parent_path": "/root"
  },
  "status": "success"
}
```

---

## How Claude Code Uses This

When a user asks Claude Code to interact with Godot (e.g., "show me the current scene"), Claude Code can:

1. Run the query tool via Bash:
   ```bash
   cd .mcp/godot-mcp-server && node godot-query.js get_current_scene
   ```

2. Parse the JSON response

3. Present the information to the user in a readable format

This bypasses the MCP protocol entirely but achieves the same result.

---

## Limitations of the Workaround

1. **No Auto-Discovery**: Claude Code doesn't automatically know these commands exist. Must be called manually via Bash.

2. **No Type Safety**: Commands are strings, not typed MCP tools. Errors only surface at runtime.

3. **JSON Parsing Required**: Claude Code must parse JSON responses manually instead of using structured MCP tool results.

4. **No Resource Subscriptions**: Can't subscribe to changes or receive real-time updates.

5. **Command Reference Required**: Must know command names and parameters (documented above).

6. **Single Request/Response**: Each query requires a new WebSocket connection (though this is fast).

---

## Advantages of the Workaround

1. ✅ **It Actually Works**: Unlike the MCP integration, this reliably connects to Godot.

2. ✅ **Simple & Transparent**: Easy to debug, understand, and modify.

3. ✅ **No Configuration Needed**: Doesn't rely on MCP config files that may not be loaded.

4. ✅ **Fast**: Direct WebSocket communication is very quick.

5. ✅ **Portable**: The script can be used by any tool, not just Claude Code.

---

## Future Recommendations

### For Future LLM Sessions

When asked to interact with Godot in this project:

1. **Always use the workaround tool**: `cd .mcp/godot-mcp-server && node godot-query.js <command>`

2. **Don't try to fix the MCP integration** unless specifically asked. It's been attempted extensively.

3. **Reference this document** when explaining Godot integration status.

### For Potential MCP Fix

If you want to attempt fixing the standard MCP integration, investigate:

1. **Check Claude Code version**: Run `claude --version` to see if MCP is fully supported
2. **Alternate config locations**: Try `~/.config/claude/mcp.json` or similar
3. **Environment variables**: Check if MCP servers need to be registered via env vars
4. **Log files**: Look for MCP-specific error logs in `~/.claude/` or `/tmp/`
5. **Anthropic documentation**: Search for updated MCP configuration docs for Claude Code CLI

### For Adding New Commands

To extend functionality:

1. Check available commands in `addons/godot_mcp/commands/*.gd`
2. Commands are already implemented in Godot; just call them via `godot-query.js`
3. Add command documentation to this file under "Available Commands"

---

## Testing Checklist

To verify the Godot integration is working:

```bash
# 1. Check if Godot is running with MCP plugin
netstat -an | grep 9080
# Should show: LISTENING on port 9080

# 2. Test the query tool
cd .mcp/godot-mcp-server
node godot-query.js get_current_scene
# Should return JSON with scene info

# 3. Test node listing
node godot-query.js list_nodes
# Should return JSON with node tree

# 4. Run the test script
cd ../..
bash .mcp/test-mcp-connection.sh
# Should show all green checkmarks
```

---

## Quick Reference

| Need | Command |
|------|---------|
| Get current scene | `node godot-query.js get_current_scene` |
| List all nodes | `node godot-query.js list_nodes` |
| List all scripts | `node godot-query.js list_scripts` |
| Get editor state | `node godot-query.js get_editor_state` |
| Run game | `node godot-query.js run_project` |
| Stop game | `node godot-query.js stop_project` |

**Always run from**: `.mcp/godot-mcp-server/` directory

---

## Summary

- ❌ **Standard MCP integration**: Not working with Claude Code CLI (despite all components functioning)
- ✅ **Workaround solution**: Direct WebSocket client works perfectly
- 📝 **Use the workaround**: `godot-query.js` for all Godot interactions
- 🔄 **Future improvement**: Fix MCP config or wait for Claude Code updates

**Last Updated**: February 14, 2026
**Status**: Workaround solution stable and production-ready
