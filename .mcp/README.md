# Godot MCP Server Setup

This directory contains the ee0pdt/Godot-MCP server for Claude Code integration.

⚠️ **IMPORTANT**: Standard MCP integration is not working with Claude Code CLI. See [GODOT_MCP_INTEGRATION.md](GODOT_MCP_INTEGRATION.md) for the current status and **working workaround solution**.

## What's Installed

### 1. Godot Addon
- **Location**: `addons/godot_mcp/`
- **Function**: Runs inside Godot Editor, provides WebSocket server for MCP communication
- **Previous addon backed up to**: `addons/godot_mcp.backup/`

### 2. Node.js MCP Server
- **Location**: `.mcp/godot-mcp-server/`
- **Function**: Bridges Claude Code to Godot via MCP protocol
- **Entry Point**: `.mcp/godot-mcp-server/dist/index.js`

### 3. MCP Configuration
- **Location**: `.claude/mcp.json`
- **Function**: Tells Claude Code how to launch the MCP server

## How to Enable

### Step 1: Enable the Addon in Godot
1. Open the project in Godot Editor
2. Go to **Project → Project Settings → Plugins**
3. Find **"Godot MCP"** and enable it
4. You should see the MCP server start in the Godot console

### Step 2: Restart Claude Code
If you're running Claude Code in a session, restart it to pick up the new MCP configuration.

## Available MCP Commands

Once enabled, you can use these commands in Claude Code:

### Node Commands
- `get-scene-tree` - Get current scene structure
- `get-node-properties` - Get properties of a node
- `create-node` - Create a new node
- `delete-node` - Remove a node
- `modify-node` - Update node properties

### Script Commands
- `list-project-scripts` - List all GDScript files
- `read-script` - Read a script file
- `modify-script` - Update script content
- `create-script` - Create new script
- `analyze-script` - Analyze script for issues

### Scene Commands
- `list-project-scenes` - List all scenes
- `read-scene` - Read scene structure
- `create-scene` - Create new scene
- `save-scene` - Save current scene

### Project Commands
- `get-project-settings` - Get project settings
- `list-project-resources` - List resources

### Editor Commands
- `get-editor-state` - Get editor state
- `run-project` - Run the game
- `stop-project` - Stop running game

## Usage Examples

### In Claude Code conversation:
```
Can you show me the current scene tree?
```
Claude will use `get-scene-tree` to fetch the scene structure.

```
Create a new Node3D called "Player" and add it to the root
```
Claude will use `create-node` to add the node.

```
Read the player.gd script and help me optimize it
```
Claude will use `read-script` to access the file.

## Troubleshooting

### MCP Server Not Connecting
1. Make sure Godot is open with the plugin enabled
2. Check Godot console for MCP server messages
3. Restart Claude Code session

### Plugin Not Showing in Godot
1. Make sure `addons/godot_mcp/` exists
2. Reload the Godot project
3. Check Godot console for errors

## Source
- **Repository**: https://github.com/ee0pdt/Godot-MCP
- **License**: MIT
