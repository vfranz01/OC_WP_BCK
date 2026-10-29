#!/bin/bash

# Backup Monitor: Heartbeat-driven validation and repair.
# Runs validate_backup.sh and auto-triggers snapshots if needed.
BACKUP_DIR="/home/node/.openclaw/workspace/backups"
LOG_FILE="/home/node/.openclaw/workspace/memory/backup_incidents.log"
VALIDATE_SCRIPT="/home/node/.openclaw/workspace/scripts/validate_backup.sh"
TRIGGER_SCRIPT="/home/node/.openclaw/workspace/scripts/trigger_backup_snapshot.sh"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S UTC')] $1" >> "$LOG_FILE"
}

# Ensure log file exists
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log "INFO: Starting backup monitor"

# Run validation
if ! bash "$VALIDATE_SCRIPT"; then
  log "WARNING: Backup validation failed. Attempting to trigger new snapshot..."
  
  # Trigger snapshot with retry
  if bash "$TRIGGER_SCRIPT" --force; then
    log "SUCCESS: New snapshot created after validation failure"
  else
    log "ERROR: Failed to create snapshot after validation failure"
    exit 1
  fi
else
  log "INFO: Backup validation passed"
fi

# Check for stale backups (older than 24h)
LATEST_BACKUP=$(ls -t "$BACKUP_DIR" | head -n 1)
if [ -n "$LATEST_BACKUP" ]; then
  LATEST_BACKUP_TIME=$(stat -c %Y "$BACKUP_DIR/$LATEST_BACKUP")
  CURRENT_TIME=$(date +%s)
  TIME_DIFF=$(( (CURRENT_TIME - LATEST_BACKUP_TIME) / 3600 ))
  
  if [ "$TIME_DIFF" -ge 24 ]; then
    log "WARNING: No recent backup (last: $LATEST_BACKUP, $TIME_DIFF hours old). Triggering new snapshot..."
    if bash "$TRIGGER_SCRIPT"; then
      log "SUCCESS: New snapshot created for stale backup"
    else
      log "ERROR: Failed to create snapshot for stale backup"
      exit 1
    fi
  fi
fi

log "INFO: Backup monitor completed successfully"