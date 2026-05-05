#!/bin/bash
# Daily Status Summary Script
# Creates/updates daily memory log with system health checks
# Designed to run during heartbeat checks (~1-2x daily)

WORKSPACE_DIR="/home/node/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE_DIR/memory"
TODAY=$(date +%Y-%m-%d)
DAILY_LOG="$MEMORY_DIR/$TODAY.md"

# Ensure memory directory exists
mkdir -p "$MEMORY_DIR"

# Function to log status
log_status() {
  local timestamp=$(date '+%H:%M UTC')
  local message="$1"
  echo "  - **[$timestamp]** $message"
}

# Check backup status
check_backup() {
  if [ -f "$WORKSPACE_DIR/scripts/validate_backup.sh" ]; then
    bash "$WORKSPACE_DIR/scripts/validate_backup.sh" > /tmp/backup_check.log 2>&1
    if [ $? -eq 0 ]; then
      echo "✅ Backup valid"
    else
      echo "⚠️  Backup check failed"
    fi
  fi
}

# Check curl allowedDomains (from TOOLS.md note)
check_curl_domains() {
  if grep -q "safeBinProfiles" /opt/openclaw/data/openclaw.json 2>/dev/null; then
    local domains=$(grep -A2 "allowedDomains" /opt/openclaw/data/openclaw.json 2>/dev/null | wc -l)
    if [ "$domains" -gt 2 ]; then
      echo "✅ curl allowedDomains configured"
    else
      echo "⚠️  curl allowedDomains may be empty"
    fi
  fi
}

# Check critical files exist
check_critical_files() {
  local files=("MEMORY.md" "AGENTS.md" "TOOLS.md" "SOUL.md" "USER.md")
  local missing=0
  for file in "${files[@]}"; do
    if [ ! -f "$WORKSPACE_DIR/$file" ]; then
      ((missing++))
    fi
  done
  if [ $missing -eq 0 ]; then
    echo "✅ All critical files present"
  else
    echo "⚠️  Missing $missing critical file(s)"
  fi
}

# Check if today's log already exists
if [ -f "$DAILY_LOG" ]; then
  # Append to existing log (update status section)
  echo "" >> "$DAILY_LOG"
  echo "## Status Check — $(date '+%H:%M UTC')" >> "$DAILY_LOG"
else
  # Create new daily log with header
  cat > "$DAILY_LOG" <<EOF
# $(date '+%Y-%m-%d') — Daily Status Log

## Overview
Automated daily health checks and status tracking.

## Status Checks — $(date '+%H:%M UTC')
EOF
fi

# Run checks and append results
{
  log_status "$(check_backup)"
  log_status "$(check_curl_domains)"
  log_status "$(check_critical_files)"
  log_status "System healthy at $(date '+%Y-%m-%d %H:%M UTC')"
} >> "$DAILY_LOG"

# Summary output
echo "✅ Daily status summary updated: $DAILY_LOG"
echo "   - $(wc -l < "$DAILY_LOG") lines logged"
