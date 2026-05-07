#!/bin/bash
# Quick Health Check — Fast status probe for heartbeat use
# Returns 0 = OK, non-zero = issues detected
# Use: bash health-quick-check.sh && echo "All good" || echo "Check logs"

WORKSPACE_DIR="/home/node/.openclaw/workspace"
ISSUES=0

echo "🔍 System Health Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Backup validation
if bash "$WORKSPACE_DIR/scripts/validate_backup.sh" > /tmp/backup_check.log 2>&1; then
  echo "✅ Backup system operational"
else
  echo "⚠️  Backup validation failed"
  ((ISSUES++))
fi

# 2. Critical files
MISSING_FILES=()
for file in MEMORY.md AGENTS.md TOOLS.md SOUL.md USER.md; do
  if [ ! -f "$WORKSPACE_DIR/$file" ]; then
    MISSING_FILES+=("$file")
  fi
done

if [ ${#MISSING_FILES[@]} -eq 0 ]; then
  echo "✅ All critical files present"
else
  echo "⚠️  Missing files: ${MISSING_FILES[*]}"
  ((ISSUES++))
fi

# 3. Scripts executable
SCRIPT_DIR="$WORKSPACE_DIR/scripts"
UNEXECUTABLE=()
for script in snapshot.sh validate_backup.sh trigger_backup_snapshot.sh daily-status-summary.sh; do
  if [ -f "$SCRIPT_DIR/$script" ] && [ ! -x "$SCRIPT_DIR/$script" ]; then
    UNEXECUTABLE+=("$script")
  fi
done

if [ ${#UNEXECUTABLE[@]} -eq 0 ]; then
  echo "✅ All critical scripts executable"
else
  echo "⚠️  Non-executable: ${UNEXECUTABLE[*]}"
  ((ISSUES++))
fi

# 4. Recent memory activity
LAST_LOG=$(ls -t "$WORKSPACE_DIR/memory"/20*.md 2>/dev/null | head -1)
if [ -n "$LAST_LOG" ]; then
  DAYS_AGO=$(( ($(date +%s) - $(stat -c %Y "$LAST_LOG")) / 86400 ))
  if [ "$DAYS_AGO" -le 1 ]; then
    echo "✅ Recent memory logs"
  else
    echo "⚠️  Memory logs stale ($DAYS_AGO days old)"
    ((ISSUES++))
  fi
else
  echo "⚠️  No memory logs found"
  ((ISSUES++))
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ISSUES -eq 0 ]; then
  echo "✅ All systems healthy"
  exit 0
else
  echo "⚠️  Found $ISSUES issue(s) — review logs"
  exit 1
fi
