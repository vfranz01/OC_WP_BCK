#!/bin/bash

# Backup Validation Script
# Validates critical workspace files and triggers a snapshot if validation fails.

WORKSPACE_DIR="/home/node/.openclaw/workspace"
BACKUP_INCIDENTS_LOG="$WORKSPACE_DIR/memory/backup_incidents.log"
SNAPSHOT_SCRIPT="$WORKSPACE_DIR/scripts/trigger_backup_snapshot.sh"
CRITICAL_FILES=("MEMORY.md" "AGENTS.md" "TOOLS.md")

# Create backup incidents log if it doesn't exist
mkdir -p "$WORKSPACE_DIR/memory"
touch "$BACKUP_INCIDENTS_LOG"

# Validate critical files
validation_failed=false
for file in "${CRITICAL_FILES[@]}"; do
  file_path="$WORKSPACE_DIR/$file"
  if [ ! -f "$file_path" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Critical file $file is missing." >> "$BACKUP_INCIDENTS_LOG"
    validation_failed=true
  elif [ ! -s "$file_path" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Critical file $file is empty." >> "$BACKUP_INCIDENTS_LOG"
    validation_failed=true
  fi
done

# Trigger snapshot if validation failed
if [ "$validation_failed" = true ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Validation failed. Triggering snapshot..." >> "$BACKUP_INCIDENTS_LOG"
  bash "$SNAPSHOT_SCRIPT" "backup_validation_failed"
  exit 1
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Validation passed. All critical files are intact." >> "$BACKUP_INCIDENTS_LOG"
  exit 0
fi