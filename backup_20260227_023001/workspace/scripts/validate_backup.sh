#!/bin/bash

# Backup Validation Script
# Purpose: Validate GitHub backup and trigger self-healing if corrupted/missing.
# Usage: Run daily via heartbeat or cron.

set -euo pipefail

# Config
BACKUP_REPO="vfranz01/OC_WP_BCK"
WORKSPACE="/home/node/.openclaw/workspace"
LOG_DIR="$WORKSPACE/logs"
LOG_FILE="$LOG_DIR/backup_validation.log"
SNAPSHOT_SCRIPT="$WORKSPACE/scripts/snapshot.sh"
CRITICAL_FILES=("MEMORY.md" "AGENTS.md" "TOOLS.md" "openclaw.json")

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Validate backup
validate_backup() {
    log "Starting backup validation..."
    
    # Check if backup repo is accessible
    if ! git ls-remote "https://github.com/$BACKUP_REPO.git" &> /dev/null; then
        log "ERROR: Backup repo $BACKUP_REPO is inaccessible."
        return 1
    fi
    
    # Check if critical files exist in the latest backup
    for file in "${CRITICAL_FILES[@]}"; do
        if ! curl -s "https://api.github.com/repos/$BACKUP_REPO/contents/$file" | grep -q '"name": "'