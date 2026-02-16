// Quick test to verify Godot WebSocket connection
const WebSocket = require('ws');

console.log('Attempting to connect to Godot WebSocket at ws://localhost:9080...');

const ws = new WebSocket('ws://localhost:9080');

ws.on('open', function open() {
  console.log('✓ Connected to Godot WebSocket!');

  // Send a test command
  const testCommand = {
    type: 'get-scene-tree',
    id: 'test-' + Date.now()
  };

  console.log('Sending test command:', testCommand);
  ws.send(JSON.stringify(testCommand));
});

ws.on('message', function message(data) {
  console.log('✓ Received from Godot:', data.toString());
  ws.close();
});

ws.on('error', function error(err) {
  console.error('✗ WebSocket error:', err.message);
  process.exit(1);
});

ws.on('close', function close() {
  console.log('Connection closed');
  process.exit(0);
});

// Timeout after 5 seconds
setTimeout(() => {
  console.error('✗ Connection timeout');
  ws.close();
  process.exit(1);
}, 5000);
