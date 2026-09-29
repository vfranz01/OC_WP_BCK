#!/bin/bash
# Ensure Brain is running, auto-start if needed
set -euo pipefail

BRAIN_DIR="/home/node/.openclaw/workspace/brain"
TIMEOUT=2

# Check if Brain is running
if ! curl -s -o /dev/null --max-time $TIMEOUT "http://localhost:3000" 2>/dev/null; then
  echo "Brain not responding, starting..."
  cd "$BRAIN_DIR"
  nohup npm run start > /tmp/brain.log 2>&1 &
  sleep 2
  if curl -s -o /dev/null --max-time $TIMEOUT "http://localhost:3000" 2>/dev/null; then
    echo "✅ Brain started successfully"
  else
    echo "❌ Brain failed to start"
    exit 1
  fi
else
  echo "✅ Brain already running"
fi
