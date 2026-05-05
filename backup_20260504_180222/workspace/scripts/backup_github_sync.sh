#!/bin/bash
# Backup GitHub Sync — Push neue Backups zu GitHub & Support für Restore
# Läuft als root auf dem Host

set -euo pipefail

REPO_DIR="/home/node/.openclaw/workspace/backup_repo"
GITHUB_REMOTE="origin"
GITHUB_BRANCH="main"
LOG_FILE="/home/node/.openclaw/workspace/memory/backup_github_sync.log"

# Logging
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=== GitHub Backup Sync Started ==="

# Prüfe ob Repo existiert
if [ ! -d "$REPO_DIR/.git" ]; then
  log "ERROR: Git repo not found at $REPO_DIR"
  exit 1
fi

cd "$REPO_DIR"

# Fix Ownership (alles root, da host-basiert)
log "Checking Git config..."
git config user.email "backup@openclaw.local" || git config --global user.email "backup@openclaw.local"
git config user.name "OpenClaw Backup" || git config --global user.name "OpenClaw Backup"

# Stage & Commit neue Backups
log "Staging new backups..."
if git add -A 2>/dev/null; then
  log "✓ Files staged"
  
  # Check ob es was zu committen gibt
  if git diff --cached --quiet; then
    log "✓ No changes to commit"
  else
    COMMIT_MSG="Auto-backup: $(date '+%Y-%m-%d %H:%M:%S UTC')"
    if git commit -m "$COMMIT_MSG" 2>/dev/null; then
      log "✓ Committed: $COMMIT_MSG"
    else
      log "✓ Commit skipped (no changes)"
    fi
  fi
else
  log "WARNING: git add failed — permission or permission issue"
fi

# Push zu GitHub
log "Pushing to GitHub..."
if git push "$GITHUB_REMOTE" "$GITHUB_BRANCH" 2>&1 | tee -a "$LOG_FILE"; then
  log "✓ Push successful"
else
  log "ERROR: Push failed — check SSH key or GitHub access"
  exit 1
fi

log "=== GitHub Backup Sync Completed ==="
