#!/bin/bash
# Validate All Cron Jobs — Check if all 7 automation jobs are scheduled & healthy
# Purpose: Ensure the automation infrastructure is intact
# Returns: 0 = all good, 1 = issues detected
# Used by: health-quick-check.sh, daily monitoring dashboards

WORKSPACE_DIR="/home/node/.openclaw/workspace"
ISSUES=0
TOTAL_JOBS=0

# Define the 7 cron jobs that should be scheduled
# Format: "schedule|command_pattern|description|log_file"
declare -a EXPECTED_JOBS=(
  "30 2 \* \* \*|snapshot.sh|Daily Snapshot Backup (02:30 UTC)|last_snapshot.txt"
  "0 3 \* \* \*|health-quick-check.sh|Daily Health Quick-Check (03:00 UTC)|health-checks.log"
  "0 12 \* \* \*|daily-status-summary.sh|Daily Status Summary (12:00 UTC)|"
  "0 14 \* \* 1,3,5|check_tshirtbull_blogpost.sh|Blog Post Validation (Mon/Wed/Fri 14:00 UTC)|blog-checks.log"
  "0 10 \* \* 0|weekly-safety-audit.sh|Weekly Safety Audit (Sundays 10:00 UTC)|"
  "0 4 \* \* \*|check_curl_allowed_domains.sh|Curl Configuration Validation (04:00 UTC)|curl-checks.log"
  "0 5 \* \* \*|validate_backup.sh|Backup Validation (05:00 UTC)|backup-checks.log"
)

echo "🔍 Cron Job Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if crontab exists at all
if ! command -v crontab &> /dev/null; then
  echo "⚠️  crontab not available on this system"
  exit 1
fi

# Get current crontab (filter out comments and empty lines)
CURRENT_CRONTAB=$(crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$')

if [ -z "$CURRENT_CRONTAB" ]; then
  echo "⚠️  No cron jobs scheduled"
  ((ISSUES++))
else
  echo "✅ Crontab is active"
fi

echo ""
echo "Checking 7 expected cron jobs:"
echo ""

# Check each expected job
for job_def in "${EXPECTED_JOBS[@]}"; do
  IFS='|' read -r schedule pattern description logfile <<< "$job_def"
  ((TOTAL_JOBS++))
  
  # Check if pattern is in crontab
  if echo "$CURRENT_CRONTAB" | grep -F "$pattern" > /dev/null 2>&1; then
    echo "✅ $description"
    
    # If there's a log file, check recent executions
    if [ -n "$logfile" ] && [ -f "$WORKSPACE_DIR/memory/$logfile" ]; then
      # Count recent entries (last 5 lines to see trends)
      RECENT=$(tail -2 "$WORKSPACE_DIR/memory/$logfile" 2>/dev/null)
      
      # Simple heuristic: look for error indicators
      if echo "$RECENT" | grep -qiE "error|failed|critical|⚠️" 2>/dev/null; then
        echo "   ⚠️  Recent log shows issues (last execution may have failed)"
        ((ISSUES++))
      else
        echo "   📝 Last logged: $(head -c 50 <<< "$RECENT" | tr '\n' ' ')"
      fi
    fi
  else
    echo "❌ MISSING: $description"
    ((ISSUES++))
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary: $((TOTAL_JOBS - ISSUES))/$TOTAL_JOBS cron jobs verified"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ISSUES -eq 0 ]; then
  echo "✅ All cron jobs are scheduled and healthy"
  exit 0
else
  echo "⚠️  Found $ISSUES issue(s) with cron jobs"
  echo ""
  echo "💡 To fix:"
  echo "   1. On the VPS host, run:"
  echo "      bash $WORKSPACE_DIR/scripts/HOST-SETUP-CRON.sh"
  echo "   2. Or manually verify with:"
  echo "      crontab -l"
  exit 1
fi
