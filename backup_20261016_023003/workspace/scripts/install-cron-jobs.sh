#!/bin/bash
# Install Cron Jobs — Automated Workspace Maintenance
# Purpose: Set up all documented automation in a single idempotent operation
# Usage: bash install-cron-jobs.sh
# Safe: Can be run multiple times — detects existing jobs and skips duplicates

set -e

WORKSPACE_DIR="/home/node/.openclaw/workspace"
CRON_LOG="$WORKSPACE_DIR/memory/cron-install.log"
CRON_BACKUP="/home/node/.crontab.backup"

# Initialize log
mkdir -p "$WORKSPACE_DIR/memory"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$CRON_LOG"
echo "Cron Job Installation - $(date '+%Y-%m-%d %H:%M UTC')" >> "$CRON_LOG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$CRON_LOG"
echo "" | tee -a "$CRON_LOG"

# Backup existing crontab
if crontab -l > "$CRON_BACKUP" 2>/dev/null; then
  echo "✅ Backed up existing crontab to $CRON_BACKUP"
  echo "   [Existing crontab backed up to $CRON_BACKUP]" >> "$CRON_LOG"
else
  echo "ℹ️  No existing crontab found (first time setup)"
  echo "   [First-time crontab setup]" >> "$CRON_LOG"
fi
echo "" | tee -a "$CRON_LOG"

# Function to safely add a cron job (idempotent)
add_cron_job() {
  local schedule="$1"
  local command="$2"
  local description="$3"
  
  # Check if job already exists
  if crontab -l 2>/dev/null | grep -F "$command" > /dev/null 2>&1; then
    echo "   ↷ Already installed: $description"
    echo "   ↷ Skipping (already exists): $description" >> "$CRON_LOG"
    return 0
  fi
  
  # Add the job to a temporary file
  {
    crontab -l 2>/dev/null || echo ""
    echo "$schedule    $command # $description"
  } | crontab -
  
  echo "   ✅ Installed: $description"
  echo "   ✅ Added: $description" >> "$CRON_LOG"
}

echo "Installing cron jobs..."
echo "Cron Jobs:" >> "$CRON_LOG"
echo "" >> "$CRON_LOG"

# 1. Daily Snapshot @ 02:30 UTC
add_cron_job \
  "30 2 * * *" \
  "bash $WORKSPACE_DIR/scripts/snapshot.sh \"daily_auto_snapshot\" 2>&1 | tail -1 >> $WORKSPACE_DIR/memory/last_snapshot.txt" \
  "Daily Snapshot Backup (02:30 UTC)"

# 2. Daily Health Check @ 03:00 UTC
add_cron_job \
  "0 3 * * *" \
  "bash $WORKSPACE_DIR/scripts/health-quick-check.sh >> $WORKSPACE_DIR/memory/health-checks.log 2>&1" \
  "Daily Health Quick-Check (03:00 UTC)"

# 3. Daily Status Summary @ 12:00 UTC
add_cron_job \
  "0 12 * * *" \
  "bash $WORKSPACE_DIR/scripts/daily-status-summary.sh > /dev/null 2>&1" \
  "Daily Status Summary (12:00 UTC)"

# 4. Blog Post Validation (Mon/Wed/Fri @ 14:00 UTC = 00:00 AEST)
add_cron_job \
  "0 14 * * 1,3,5" \
  "bash $WORKSPACE_DIR/scripts/check_tshirtbull_blogpost.sh >> $WORKSPACE_DIR/memory/blog-checks.log 2>&1" \
  "Blog Post Validation (Mon/Wed/Fri 14:00 UTC)"

# 5. Weekly Safety Audit (Sunday @ 10:00 UTC)
add_cron_job \
  "0 10 * * 0" \
  "bash $WORKSPACE_DIR/scripts/weekly-safety-audit.sh > /dev/null 2>&1" \
  "Weekly Safety Audit (Sundays 10:00 UTC)"

# 6. Validate Curl Domains (Daily @ 04:00 UTC)
add_cron_job \
  "0 4 * * *" \
  "bash $WORKSPACE_DIR/scripts/check_curl_allowed_domains.sh >> $WORKSPACE_DIR/memory/curl-checks.log 2>&1" \
  "Curl Configuration Validation (04:00 UTC)"

# 7. Validate Backup (Daily @ 05:00 UTC)
add_cron_job \
  "0 5 * * *" \
  "bash $WORKSPACE_DIR/scripts/validate_backup.sh >> $WORKSPACE_DIR/memory/backup-checks.log 2>&1" \
  "Backup Validation (05:00 UTC)"

echo "" | tee -a "$CRON_LOG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$CRON_LOG"
echo "✅ Cron job installation complete!" | tee -a "$CRON_LOG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$CRON_LOG"
echo "" | tee -a "$CRON_LOG"

echo "📅 Current Crontab:"
echo "" | tee -a "$CRON_LOG"
crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$' | nl | tee -a "$CRON_LOG" || echo "   (no jobs scheduled)"
echo "" | tee -a "$CRON_LOG"

echo "💡 To verify installation:"
echo "   crontab -l"
echo ""
echo "💡 To remove a specific job:"
echo "   (crontab -l | grep -v 'PATTERN_TO_REMOVE') | crontab -"
echo ""
echo "💡 To remove all jobs:"
echo "   crontab -r"
echo ""
echo "💡 To restore from backup:"
echo "   crontab $CRON_BACKUP"
echo ""
echo "📊 Check logs:"
echo "   tail -f $WORKSPACE_DIR/memory/cron-install.log"
echo ""
