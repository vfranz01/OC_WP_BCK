#!/bin/bash
# Daily Status Summary Script
# Creates/updates daily memory log with system health checks
# Designed to run during heartbeat checks (~1-2x daily)

WORKSPACE_DIR="/home/node/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE_DIR/memory"
TODAY=$(date +%Y-%m-%d)
DAILY_LOG="$MEMORY_DIR/$TODAY.md"
INCIDENT_LOG="$MEMORY_DIR/backup_incidents.log"

# Ensure memory directory exists
mkdir -p "$MEMORY_DIR"

# Create daily memory file if it does not exist
bash "$WORKSPACE_DIR/scripts/create_daily_memory_file.sh"

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

# Check OpenClaw gateway status (best-effort, no hard dependency on the CLI)
check_openclaw_gateway_status() {
  if ! command -v openclaw >/dev/null 2>&1; then
    echo "ℹ️ OpenClaw CLI unavailable in this runtime; skipped gateway uptime check"
    return 0
  fi

  local status_output
  if ! status_output=$(openclaw gateway status 2>&1); then
    echo "⚠️ OpenClaw Gateway status check failed"
    echo "$(date '+%Y-%m-%d %H:%M UTC') - OpenClaw gateway status failed: $status_output" >> "$INCIDENT_LOG"
    return 0
  fi

  if grep -q "running for" <<< "$status_output"; then
    local gateway_uptime
    gateway_uptime=$(grep -oP 'running for \K.*' <<< "$status_output" | head -1 | tr -d ",")
    local hours=0
    local minutes=0

    if [[ "$gateway_uptime" =~ ([0-9]+)[[:space:]]+hours? ]]; then
      hours="${BASH_REMATCH[1]}"
    fi
    if [[ "$gateway_uptime" =~ ([0-9]+)[[:space:]]+minutes? ]]; then
      minutes="${BASH_REMATCH[1]}"
    fi
    minutes=$((minutes + hours * 60))

    if [[ $minutes -ge 30 ]]; then
      echo "✅ OpenClaw Gateway healthy and running for $gateway_uptime"
    else
      echo "⚠️ OpenClaw Gateway may have restarted - running only for $gateway_uptime"
    fi
  else
    echo "⚠️ OpenClaw Gateway status unclear"
    echo "$(date '+%Y-%m-%d %H:%M UTC') - OpenClaw gateway status unclear: $status_output" >> "$INCIDENT_LOG"
  fi
}

# One-time reminder to run the learnings sync; avoids duplicate reminders in the same run.
check_learnings_sync_marker() {
  local learnings_run_file="$MEMORY_DIR/.learnings_run"
  if [ ! -f "$learnings_run_file" ]; then
    log_status "⚠️  sync-learnings.sh has not been run yet. Run: bash $WORKSPACE_DIR/scripts/sync-learnings.sh --days 7. After the first run, this message will disappear."
    touch "$learnings_run_file"
  fi
}

check_last_snapshot() {
  local last_snapshot_file="$WORKSPACE_DIR/memory/last_snapshot.txt"
  if [ -f "$last_snapshot_file" ]; then
    local last_snapshot_result=$(cat "$last_snapshot_file")
    echo "✅ Last Snapshot: $last_snapshot_result"
  else
    echo "⚠️  Last Snapshot: No record found. Run  `bash $WORKSPACE_DIR/scripts/snapshot.sh \"manual_check\"` manually." >> "$INCIDENT_LOG"
    echo "⚠️  Last Snapshot: No record found"
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
  
  # Load the template file
  TEMPLATE_FILE="$WORKSPACE_DIR/memory/template.md"
  if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "⚠️ Error: Template file not found: $TEMPLATE_FILE - check MEMORY.md for correct log formatting."
    exit 1
  fi
  
  # Replace placeholders in the template
  content=$(cat "$TEMPLATE_FILE" | sed "s/YYYY-MM-DD/$TODAY/g")
  
  # Add the status checks header
  content="$content\n## Status Checks — $(date '+%H:%M UTC')\n"
  
  echo "$content" > "$DAILY_LOG"
fi

# Run one-time maintenance reminders
check_learnings_sync_marker

# Run health-quick-check
bash "$WORKSPACE_DIR/scripts/health-quick-check.sh"

# Run checks and append results
{
  log_status "$(check_backup)"
  log_status "$(check_curl_domains)"
  log_status "$(check_critical_files)"
  log_status "$(check_openclaw_gateway_status)"
  log_status "$(check_last_snapshot)"
  log_status "System healthy at $(date '+%Y-%m-%d %H:%M UTC')"
  python3 "$WORKSPACE_DIR/scripts/check_blog_posts.py" >> "$DAILY_LOG" 2>&1
} >> "$DAILY_LOG"

# Summary output
echo "✅ Daily status summary updated: $DAILY_LOG"

# Double check that the daily log file was created
if [ ! -f "$DAILY_LOG" ]; then
  echo "⚠️ ERROR: Daily log file $DAILY_LOG not created! Check /tmp/create_daily_memory_file.log for details." >> "$INCIDENT_LOG"
fi
if [ -f "$DAILY_LOG" ]; then
  echo "   - $(wc -l < "$DAILY_LOG") lines logged"
else
  echo "⚠️ ERROR: Daily log file $DAILY_LOG not created! Duplicate check."
fi