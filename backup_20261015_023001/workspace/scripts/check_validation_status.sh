#!/bin/bash
# Quick status check - shows validation trend and recent incidents
WORKSPACE_DIR="/home/node/.openclaw/workspace"
STATUS_FILE="$WORKSPACE_DIR/memory/.validation_status"
LOG_FILE="$WORKSPACE_DIR/memory/backup_incidents.log"

echo "=== Validation Status Check ==="

# Show last validation result
if [ -f "$STATUS_FILE" ]; then
  status=$(cat "$STATUS_FILE")
  echo "Last validation: $status"
else
  echo "Last validation: Unknown (no status file yet)"
fi

# Show recent incidents (last 5 lines)
if [ -f "$LOG_FILE" ]; then
  echo ""
  echo "Recent incidents (last 5):"
  tail -5 "$LOG_FILE" | sed 's/^/  /'
else
  echo "No incidents logged yet."
fi

# Count validation failures in last 7 days
if [ -f "$LOG_FILE" ]; then
  seven_days_ago=$(date -d '7 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-7d '+%Y-%m-%d')
  failure_count=$(grep "Validation FAILED" "$LOG_FILE" 2>/dev/null | grep -E "$seven_days_ago|$(date '+%Y-%m-%d')" | wc -l)
  if [ "$failure_count" -gt 0 ]; then
    echo ""
    echo "⚠️  Validation failures in last 7 days: $failure_count"
  fi
fi
