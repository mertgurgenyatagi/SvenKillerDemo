#!/usr/bin/env node
/**
 * Direct Godot WebSocket query tool
 * Usage: node godot-query.js <command> [args...]
 */

import WebSocket from 'ws';
import { promises as fs } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const GODOT_WS_URL = 'ws://localhost:9080';
const TIMEOUT_MS = 5000;

async function sendCommand(command, args = {}) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(GODOT_WS_URL);
    let timeout;

    timeout = setTimeout(() => {
      ws.close();
      reject(new Error(`Timeout waiting for response`));
    }, TIMEOUT_MS);

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
      try {
        const response = JSON.parse(data.toString());

        // Skip welcome message, wait for actual response
        if (response.type === 'welcome') {
          return;
        }

        clearTimeout(timeout);
        ws.close();
        resolve(response);
      } catch (err) {
        clearTimeout(timeout);
        ws.close();
        reject(new Error(`Failed to parse response: ${err.message}`));
      }
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
    console.error('Commands: get-scene-tree, get-editor-state, list-scripts, list-scenes');
    console.error('Args: key=value pairs or JSON string');
    process.exit(1);
  }

  // Parse additional arguments (key=value or JSON)
  const args = {};
  for (let i = 3; i < process.argv.length; i++) {
    const arg = process.argv[i];

    // Try to parse as JSON first
    if (arg.startsWith('{')) {
      try {
        Object.assign(args, JSON.parse(arg));
        continue;
      } catch (e) {
        // Not JSON, continue to key=value parsing
      }
    }

    // Parse as key=value
    const eqIndex = arg.indexOf('=');
    if (eqIndex > 0) {
      const key = arg.substring(0, eqIndex);
      const value = arg.substring(eqIndex + 1);
      args[key] = value;
    }
  }

  try {
    const result = await sendCommand(command, args);
    console.log(JSON.stringify(result, null, 2));
  } catch (err) {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  }
}

main();
