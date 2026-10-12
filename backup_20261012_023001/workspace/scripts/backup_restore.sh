#!/bin/bash
# Backup Restore — Backups von GitHub pullen & einspielen
# Läuft als root auf dem Host

set -euo pipefail

REPO_DIR="/home/node/.openclaw/workspace/backup_repo"
BACKUP_DATE="${1:-latest}"
RESTORE_TARGET="${2:-.}"
LOG_FILE="/home/node/.openclaw/workspace/memory/backup_restore.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=== Backup Restore Started ==="
log "Target: $BACKUP_DATE | Restore to: $RESTORE_TARGET"

# Prüfe ob Repo existiert
if [ ! -d "$REPO_DIR/.git" ]; then
  log "ERROR: Git repo not found at $REPO_DIR"
  exit 1
fi

cd "$REPO_DIR"

# Pull latest from GitHub
log "Pulling latest from GitHub..."
if git pull origin main 2>&1 | tee -a "$LOG_FILE"; then
  log "✓ Pull successful"
else
  log "ERROR: Pull failed"
  exit 1
fi

# Find backup directory
if [ "$BACKUP_DATE" = "latest" ]; then
  BACKUP_DIR=$(ls -dt backup_* 2>/dev/null | head -1)
  if [ -z "$BACKUP_DIR" ]; then
    log "ERROR: No backups found"
    exit 1
  fi
  log "Found latest backup: $BACKUP_DIR"
else
  BACKUP_DIR="backup_${BACKUP_DATE}_023001"
  if [ ! -d "$BACKUP_DIR" ]; then
    log "ERROR: Backup directory not found: $BACKUP_DIR"
    exit 1
  fi
  log "Using specified backup: $BACKUP_DIR"
fi

# Restore
log "Restoring from $BACKUP_DIR to $RESTORE_TARGET..."
if [ "$RESTORE_TARGET" = "." ]; then
  # Restore to current OpenClaw
  RESTORE_TARGET="/home/node/.openclaw"
  log "Restoring to: $RESTORE_TARGET"
fi

# Backup the current state before restoring
if [ -d "$RESTORE_TARGET" ]; then
  PRE_RESTORE_BACKUP="$RESTORE_TARGET.pre-restore.$(date '+%s').tar.gz"
  log "Creating safety backup: $PRE_RESTORE_BACKUP"
  tar -czf "$PRE_RESTORE_BACKUP" -C "$(dirname "$RESTORE_TARGET")" "$(basename "$RESTORE_TARGET")" 2>/dev/null || true
fi

# Restore files
log "Extracting backup..."
if tar -xzf "$BACKUP_DIR/workspace.tar.gz" -C "$RESTORE_TARGET" 2>/dev/null; then
  log "✓ Restore successful"
else
  log "ERROR: Extract failed — check backup integrity"
  exit 1
fi

log "=== Backup Restore Completed ==="
log "Files restored to: $RESTORE_TARGET"
