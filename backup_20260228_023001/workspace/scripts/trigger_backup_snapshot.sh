#!/bin/bash

# Script to trigger a GitHub backup snapshot and log incidents if it fails.
# Usage: ./trigger_backup_snapshot.sh

LOG_FILE="/home/node/.openclaw/workspace/memory/backup_incidents.log"
BACKUP_CMD="gh repo sync --force"

# Trigger backup
echo "$(date '+%Y-%m-%d %H:%M:%S') - Triggering backup snapshot..." >> "$LOG_FILE"
if eval "$BACKUP_CMD"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Backup snapshot completed successfully." >> "$LOG_FILE"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Backup snapshot failed. Manual intervention required." >> "$LOG_FILE"
fi