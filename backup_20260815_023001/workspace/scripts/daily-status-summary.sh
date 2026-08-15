#!/bin/bash
# Daily Status Summary Script
# Creates/updates daily memory log with system health checks
# Designed to run during heartbeat checks (~1-2x daily)

WORKSPACE_DIR="/home/node/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE_DIR/memory"
TODAY=$(date +%Y-%m-%d)
DAILY_LOG="$MEMORY_DIR/$TODAY.md"
INCIDENT_LOG="$MEMORY_DIR/backup_incidents.log"


  if [ -f "$INCIDENT_LOG" ]; then
    if [ -s "$INCIDENT_LOG" ]; then # Check if file is not empty
      YESTERDAY=$(date -d "yesterday" +%Y-%m-%d)
      mv "$INCIDENT_LOG" "${INCIDENT_LOG%.log}-${YESTERDAY}.log"
    fi
    # Create a new empty log file for today
    > "$INCIDENT_LOG" 
  else
    # Create the log file if it doesn't exist
    touch "$INCIDENT_LOG"
  fi


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

# Check curl allowedDomains (from TOOLS.md note). Reuse the dedicated
# JSON-aware validator instead of a brittle grep line-count heuristic.
check_curl_domains() {
  local validator="$WORKSPACE_DIR/scripts/check_curl_allowed_domains.sh"
  if [ ! -f "$validator" ]; then
    echo "⚠️  curl allowedDomains validator missing: $validator"
    return 0
  fi

  local validator_output
  if validator_output=$(bash "$validator" 2>&1); then
    echo "✅ curl allowedDomains configured"
  else
    echo "⚠️  curl allowedDomains may be missing — $validator_output"
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

# Run health-quick-check and capture the result so the daily log does not
# claim "System healthy" when the fast probe actually found issues.
HEALTH_LOG="$MEMORY_DIR/.last-health-quick-check.log"
HEALTH_TMP=$(mktemp)
if bash "$WORKSPACE_DIR/scripts/health-quick-check.sh" > "$HEALTH_TMP" 2>&1; then
  HEALTH_SUMMARY="✅ Quick health check passed"
else
  HEALTH_EXIT=$?
  HEALTH_SUMMARY="⚠️  Quick health check found issues (exit $HEALTH_EXIT); details saved to $HEALTH_LOG"
  echo "$(date '+%Y-%m-%d %H:%M UTC') - health-quick-check.sh failed with exit $HEALTH_EXIT; see $HEALTH_LOG" >> "$INCIDENT_LOG"
fi
cat "$HEALTH_TMP"
cp "$HEALTH_TMP" "$HEALTH_LOG"
rm -f "$HEALTH_TMP"

# Run checks once, then derive the final summary from all results so a warning
# cannot be followed by a misleading "System healthy" line.
BACKUP_SUMMARY="$(check_backup)"
CURL_DOMAINS_SUMMARY="$(check_curl_domains)"
CRITICAL_FILES_SUMMARY="$(check_critical_files)"
GATEWAY_SUMMARY="$(check_openclaw_gateway_status)"
LAST_SNAPSHOT_SUMMARY="$(check_last_snapshot)"

OVERALL_STATUS="healthy"
for status_line in \
  "$HEALTH_SUMMARY" \
  "$BACKUP_SUMMARY" \
  "$CURL_DOMAINS_SUMMARY" \
  "$CRITICAL_FILES_SUMMARY" \
  "$GATEWAY_SUMMARY" \
  "$LAST_SNAPSHOT_SUMMARY"; do
  if [[ "$status_line" == *"⚠️"* || "$status_line" == *"❌"* ]]; then
    OVERALL_STATUS="degraded"
    break
  fi
done

# Run checks and append results
{
  log_status "$HEALTH_SUMMARY"
  log_status "$BACKUP_SUMMARY"
  log_status "$CURL_DOMAINS_SUMMARY"
  log_status "$CRITICAL_FILES_SUMMARY"
  log_status "$GATEWAY_SUMMARY"
  log_status "$LAST_SNAPSHOT_SUMMARY"
  if [ "$OVERALL_STATUS" = "healthy" ]; then
    log_status "System healthy at $(date '+%Y-%m-%d %H:%M UTC')"
  else
    log_status "System degraded at $(date '+%Y-%m-%d %H:%M UTC') — review $HEALTH_LOG and $INCIDENT_LOG"
  fi
  python3 "$WORKSPACE_DIR/scripts/check_blog_posts.py" >> "$DAILY_LOG" 2>&1
} >> "$DAILY_LOG"

# New: Run learning distillation script and log output
DISTILLATION_OUTPUT_FILE="$MEMORY_DIR/.potential_learnings.md" # Temporary file for distillation output
DISTILLATION_SCRIPT="$WORKSPACE_DIR/scripts/distill-learnings.sh" # Path to the bash script

if [ -f "$DISTILLATION_SCRIPT" ] && [ -x "$DISTILLATION_SCRIPT" ]; then
  if bash "$DISTILLATION_SCRIPT" > "$DISTILLATION_OUTPUT_FILE" 2>&1; then
    if [ -s "$DISTILLATION_OUTPUT_FILE" ]; then # Check if file is not empty
      log_status "📝 Potential learnings distilled. Review '\''$DISTILLATION_OUTPUT_FILE'\'' for manual promotion to MEMORY.md."
      # Keep the file for review; it will be cleaned up manually or by other processes.
    else
      # If the output file is empty after running the script (meaning no learnings found)
      rm "$DISTILLATION_OUTPUT_FILE" # Clean up empty file
    fi
  else
    log_status "⚠️ Failed to run learning distillation script. Check output in '\''$DISTILLATION_OUTPUT_FILE'\''."
  fi
else
  log_status "⚠️ Learning distillation script not found or not executable at '\''$DISTILLATION_SCRIPT'\''."
fi

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
