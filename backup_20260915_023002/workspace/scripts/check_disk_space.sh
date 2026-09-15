#!/bin/bash
# Check Disk Space Script
# Monitors the root partition for high disk usage.

WORKSPACE_DIR="/home/node/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE_DIR/memory"
INCIDENT_LOG="$MEMORY_DIR/backup_incidents.log"

# Thresholds
WARN_THRESHOLD=90
CRITICAL_THRESHOLD=95

# Get disk usage percentage for '/' (root partition)
# Use 'df --output=pcent /' and extract the percentage value.
# tail -n 1 removes the header line.
# cut -c 2- removes leading spaces.
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')

TIMESTAMP=$(date '+%Y-%m-%d %H:%M UTC')

if [ -z "$DISK_USAGE" ]; then
  echo "$TIMESTAMP - ⚠️ Disk usage check failed: Could not retrieve usage for /" >> "$INCIDENT_LOG"
  echo "⚠️ Disk usage check failed: Could not retrieve usage for /"
  exit 1 # Indicate failure
fi

# Compare with thresholds
if [ "$DISK_USAGE" -ge "$CRITICAL_THRESHOLD" ]; then
  echo "$TIMESTAMP - ❌ CRITICAL: Disk usage on / is at $DISK_USAGE% (exceeds $CRITICAL_THRESHOLD%)" >> "$INCIDENT_LOG"
  echo "  - ❌ CRITICAL: Disk usage on / is at $DISK_USAGE% (exceeds $CRITICAL_THRESHOLD%)"
  exit 1 # Indicate critical failure
elif [ "$DISK_USAGE" -ge "$WARN_THRESHOLD" ]; then
  echo "$TIMESTAMP - ⚠️ Disk usage on / is at $DISK_USAGE% (exceeds $WARN_THRESHOLD%)" >> "$INCIDENT_LOG"
  echo "  - ⚠️ Disk usage on / is at $DISK_USAGE% (exceeds $WARN_THRESHOLD%)"
  # Do not exit with error code for warning, as script should continue
else
  echo "✅ Disk usage on / is at $DISK_USAGE% (below $WARN_THRESHOLD%)"
fi
exit 0 # Indicate success at or below warning threshold
