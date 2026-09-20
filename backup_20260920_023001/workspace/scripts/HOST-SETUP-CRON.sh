#!/bin/bash
# HOST-LEVEL CRON SETUP — Run this on the Hostinger VPS host (NOT in Docker container)
# Purpose: Set up automated workspace maintenance via host crontab
# Usage: On the VPS host, run: bash /home/node/.openclaw/workspace/scripts/HOST-SETUP-CRON.sh
#
# ⚠️  IMPORTANT: This script MUST be run on the HOST (Hostinger VPS), not inside Docker
# The scripts will execute via: docker exec openclaw-openclaw-gateway-1 bash ...

set -e

WORKSPACE_DIR="/home/node/.openclaw/workspace"
CRON_LOG="$WORKSPACE_DIR/memory/cron-install.log"
CRON_BACKUP="/home/node/.crontab.backup"

# Verify we're running on the host (not in container)
if [ ! -d "/var/run/docker.sock" ] && ! ls /.dockerenv > /dev/null 2>&1; then
  # We're on the host, which is good. But let's be more certain.
  if ! command -v docker &> /dev/null; then
    echo "❌ ERROR: Docker not found. This script must run on the Hostinger VPS host."
    echo "   Make sure you're running this on the HOST, not inside the container."
    exit 1
  fi
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 HOST-Level Cron Job Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Initialize log
mkdir -p "$WORKSPACE_DIR/memory"
{
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "HOST-Level Cron Installation - $(date '+%Y-%m-%d %H:%M UTC')"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
} >> "$CRON_LOG"

# Backup existing crontab
if crontab -l > "$CRON_BACKUP" 2>/dev/null; then
  echo "✅ Backed up existing crontab to $CRON_BACKUP"
  echo "   [Existing crontab backed up to $CRON_BACKUP]" >> "$CRON_LOG"
else
  echo "ℹ️  No existing crontab found (first time setup)"
  echo "   [First-time crontab setup]" >> "$CRON_LOG"
  > "$CRON_BACKUP"  # Create empty backup
fi
echo ""

# Function to safely add a cron job (idempotent)
add_cron_job() {
  local schedule="$1"
  local command="$2"
  local description="$3"
  
  # Check if job already exists (by unique portion of command)
  local unique_marker=$(echo "$command" | awk '{print $NF}' | head -c20)  # Last part of command
  
  if crontab -l 2>/dev/null | grep -F "$unique_marker" > /dev/null 2>&1; then
    echo "   ↷ Already installed: $description"
    {
      echo "   ↷ Skipping (already exists): $description"
    } >> "$CRON_LOG"
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

echo "Installing host-level cron jobs..."
{
  echo "Cron Jobs:"
  echo ""
} >> "$CRON_LOG"

# All commands execute via docker exec to run inside container
DOCKER_CMD="docker exec openclaw-openclaw-gateway-1"

# 1. Daily Snapshot @ 02:30 UTC
add_cron_job \
  "30 2 * * *" \
  "$DOCKER_CMD bash $WORKSPACE_DIR/scripts/snapshot.sh \"daily_auto_snapshot\" 2>&1 | tail -1 >> $WORKSPACE_DIR/memory/last_snapshot.txt" \
  "Daily Snapshot Backup (02:30 UTC)"

# 2. Daily Health Check @ 03:00 UTC
add_cron_job \
  "0 3 * * *" \
  "$DOCKER_CMD bash $WORKSPACE_DIR/scripts/health-quick-check.sh >> $WORKSPACE_DIR/memory/health-checks.log 2>&1" \
  "Daily Health Quick-Check (03:00 UTC)"

# 3. Daily Status Summary @ 12:00 UTC
add_cron_job \
  "0 12 * * *" \
  "$DOCKER_CMD bash $WORKSPACE_DIR/scripts/daily-status-summary.sh > /dev/null 2>&1" \
  "Daily Status Summary (12:00 UTC)"

# 4. Blog Post Validation (Mon/Wed/Fri @ 14:00 UTC)
add_cron_job \
  "0 14 * * 1,3,5" \
  "$DOCKER_CMD bash $WORKSPACE_DIR/scripts/check_tshirtbull_blogpost.sh >> $WORKSPACE_DIR/memory/blog-checks.log 2>&1" \
  "Blog Post Validation (Mon/Wed/Fri 14:00 UTC)"

# 5. Weekly Safety Audit (Sunday @ 10:00 UTC)
add_cron_job \
  "0 10 * * 0" \
  "$DOCKER_CMD bash $WORKSPACE_DIR/scripts/weekly-safety-audit.sh > /dev/null 2>&1" \
  "Weekly Safety Audit (Sundays 10:00 UTC)"

# 6. Validate Curl Domains (Daily @ 04:00 UTC)
add_cron_job \
  "0 4 * * *" \
  "$DOCKER_CMD bash $WORKSPACE_DIR/scripts/check_curl_allowed_domains.sh >> $WORKSPACE_DIR/memory/curl-checks.log 2>&1" \
  "Curl Configuration Validation (04:00 UTC)"

# 7. Validate Backup (Daily @ 05:00 UTC)
add_cron_job \
  "0 5 * * *" \
  "$DOCKER_CMD bash $WORKSPACE_DIR/scripts/validate_backup.sh >> $WORKSPACE_DIR/memory/backup-checks.log 2>&1" \
  "Backup Validation (05:00 UTC)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Cron job installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📅 Current Host Crontab:"
echo ""
crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$' | nl || echo "   (no jobs scheduled)"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 Useful Commands:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "View all cron jobs:"
echo "  crontab -l"
echo ""
echo "Edit crontab (GUI):"
echo "  crontab -e"
echo ""
echo "Remove a specific job:"
echo "  (crontab -l | grep -v 'PATTERN_TO_REMOVE') | crontab -"
echo ""
echo "Restore from backup:"
echo "  crontab $CRON_BACKUP"
echo ""
echo "Monitor logs:"
echo "  tail -f $WORKSPACE_DIR/memory/health-checks.log"
echo "  tail -f $WORKSPACE_DIR/memory/blog-checks.log"
echo "  tail -f $WORKSPACE_DIR/memory/cron-install.log"
echo ""
echo "Test a cron job manually:"
echo "  docker exec openclaw-openclaw-gateway-1 bash $WORKSPACE_DIR/scripts/daily-status-summary.sh"
echo ""

{
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ Installation complete - $(date '+%Y-%m-%d %H:%M UTC')"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
} >> "$CRON_LOG"

echo "✅ Log saved to: $CRON_LOG"
