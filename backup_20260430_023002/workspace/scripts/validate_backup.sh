#!/bin/bash
# Ensure this script is executable
if [ ! -x "$0" ]; then
  log "ERROR: Validate script is not executable. Aborting."
  exit 1
fi


# Backup Validation Script - Enhanced
# Validates critical workspace files, backup system health, and triggers a snapshot if validation fails.

WORKSPACE_DIR="/home/node/.openclaw/workspace"
BACKUP_INCIDENTS_LOG="$WORKSPACE_DIR/memory/backup_incidents.log"
SNAPSHOT_SCRIPT="$WORKSPACE_DIR/scripts/trigger_backup_snapshot.sh"
BACKUP_DIR="/home/node/.openclaw/backups"
CRITICAL_FILES=("MEMORY.md" "AGENTS.md" "TOOLS.md" "HEARTBEAT.md" "SOUL.md" "USER.md")
VALIDATION_PASSED=true
TMP_LOG=$(mktemp)

# Cleanup on exit
cleanup() { rm -f "$TMP_LOG"; }
trap cleanup EXIT

# Log helper - writes to both main log and temp log
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$BACKUP_INCIDENTS_LOG" "$TMP_LOG"; }

# Ensure backup incidents log directory exists
mkdir -p "$WORKSPACE_DIR/memory"
touch "$BACKUP_INCIDENTS_LOG" 2>/dev/null || true

log "=== Starting backup validation ==="

# Validate critical files exist and are non-empty
for file in "${CRITICAL_FILES[@]}"; do
  file_path="$WORKSPACE_DIR/$file"
  if [ ! -f "$file_path" ]; then
    log "ERROR: Critical file $file is missing."
    VALIDATION_PASSED=false
  elif [ ! -s "$file_path" ]; then
    log "ERROR: Critical file $file is empty."
    VALIDATION_PASSED=false
  else
    log "OK: $file validated."
  bash "$WORKSPACE_DIR/scripts/validate_critical_rules.sh" >> "$TMP_LOG" 2>&1
  fi
done

# Validate snapshot script exists and is executable
if [ ! -f "$SNAPSHOT_SCRIPT" ]; then
  log "ERROR: Snapshot script $SNAPSHOT_SCRIPT is missing."
  VALIDATION_PASSED=false
elif [ ! -x "$SNAPSHOT_SCRIPT" ]; then
  log "WARNING: Snapshot script not executable. Attempting chmod +x..."
  chmod +x "$SNAPSHOT_SCRIPT" 2>/dev/null || true
  if [ -x "$SNAPSHOT_SCRIPT" ]; then
    log "OK: Snapshot script is now executable."
  else
    log "ERROR: Snapshot script still not executable after chmod attempt."
    VALIDATION_PASSED=false
  fi
else
  log "OK: Snapshot script is executable."
fi

# Validate backup directory
if [ -d "$BACKUP_DIR" ]; then
  log "OK: Backup directory exists at $BACKUP_DIR."
  
  # Check for recent snapshots (within last 24 hours)
  recent_snapshot=$(find "$BACKUP_DIR" -name "snapshot-*.tar.gz" -mtime -1 2>/dev/null | head -n1)
  if [ -n "$recent_snapshot" ]; then
    log "OK: Recent snapshot found: $(basename "$recent_snapshot")."
  else
    log "WARNING: No snapshots created in the last 24 hours. Backup process may be failing."
  fi
else
  log "WARNING: Backup directory $BACKUP_DIR not found (will be created by snapshot script if needed)."
fi

# Improved final decision
if [ "$VALIDATION_PASSED" = true ]; then
  log "Validation passed. All critical checks successful."
  log "Backup validation completed successfully."
  exit 0
else
  log "Validation FAILED. Triggering emergency snapshot for recovery..."
  if [ -x "$SNAPSHOT_SCRIPT" ]; then
    bash "$SNAPSHOT_SCRIPT" "validation_failed" >> "$BACKUP_INCIDENTS_LOG" 2>&1
    if [ $? -eq 0 ]; then
      log "OK: Emergency snapshot triggered successfully."
    else
      log "ERROR: Emergency snapshot failed. See $BACKUP_INCIDENTS_LOG for details."
    fi
  else
    log "ERROR: Cannot trigger snapshot - script not executable. Aborting."
  fi
  exit 1
fi
