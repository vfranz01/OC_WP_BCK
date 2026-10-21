#!/bin/bash
# Backup GitHub Sync — Push neue Backups zu GitHub
# Läuft als root auf dem Host mit SSH-Key Zugriff

set -euo pipefail

REPO_DIR="/home/node/.openclaw/workspace/backup_repo"
GITHUB_REMOTE="origin"
GITHUB_BRANCH="main"
LOG_FILE="/home/node/.openclaw/workspace/memory/backup_github_sync.log"
SSH_KEY="/root/.ssh/id_ed25519"

# Logging
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=== GitHub Backup Sync Started ==="

# Prüfe SSH-Key
if [ ! -f "$SSH_KEY" ]; then
  log "ERROR: SSH key not found at $SSH_KEY"
  exit 1
fi

# Prüfe ob Repo existiert
if [ ! -d "$REPO_DIR/.git" ]; then
  log "ERROR: Git repo not found at $REPO_DIR"
  exit 1
fi

cd "$REPO_DIR"

# Git config als global (root user)
log "Checking Git config..."
git config --global user.email "backup@openclaw.local"
git config --global user.name "OpenClaw Backup"

# SSH-Key für Git setzen
export GIT_SSH_COMMAND="ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new"

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
  STATUS="✅ Backup Push erfolgreich"
  DETAILS="Backups wurden zu GitHub gepusht"
else
  log "ERROR: Push failed — check SSH key or GitHub access"
  STATUS="❌ Backup Push fehlgeschlagen"
  DETAILS="SSH-Key oder GitHub-Zugriff Problem. Siehe /var/log/backup-github.log"
fi

log "=== GitHub Backup Sync Completed ==="

# Telegram Benachrichtigung — via telegram-send.sh (2026-10-11):
# delivery-verified (ok:true) statt stiller 401-Failures; Token-Auswahl aus
# env/openclaw.json statt hardcodiertem, rotiertem Token (Outage 2026-09-23).
log "Sending Telegram notification..."
MESSAGE=$(printf '%b' "$STATUS\n\n📅 $(date '+%Y-%m-%d %H:%M:%S UTC')\n$DETAILS\n\n🔗 https://github.com/vfranz01/OC_WP_BCK")
if bash /home/node/.openclaw/workspace/scripts/telegram-send.sh "$MESSAGE"; then
  log "✓ Telegram notification delivered"
else
  log "WARNING: Telegram notification NOT delivered — see memory/telegram-deliveries.log"
fi
