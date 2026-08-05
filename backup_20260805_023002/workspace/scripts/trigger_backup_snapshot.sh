#!/bin/bash

# Auto-Snapshot Script
# Triggers a snapshot of the workspace and logs the incident.

WORKSPACE_DIR="/home/node/.openclaw/workspace"
BACKUP_INCIDENTS_LOG="$WORKSPACE_DIR/memory/backup_incidents.log"
REASON="$1"

# Log the incident
if [ -z "$REASON" ]; then
  REASON="manual_trigger"
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Snapshot triggered due to: $REASON" >> "$BACKUP_INCIDENTS_LOG"

# Trigger snapshot
bash "$WORKSPACE_DIR/scripts/snapshot.sh" "$REASON"