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
  DAYS_AGO=$(( ($(date -u +%s) - $(stat -c %Y "$LAST_LOG")) / 86400 ))
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

# 5. Memory file format validation (auto-repairs missing frontmatter)
if bash "$WORKSPACE_DIR/scripts/validate-memory-files.sh" > /tmp/memory_validation.log 2>&1; then
  echo "✅ Memory files properly formatted"
else
  echo "⚠️  Memory file format issues detected — attempting auto-repair"
  if bash "$WORKSPACE_DIR/scripts/fix-memory-frontmatter.sh" > /tmp/memory_fix.log 2>&1; then
    if bash "$WORKSPACE_DIR/scripts/validate-memory-files.sh" > /tmp/memory_revalidation.log 2>&1; then
      echo "   ✅ Auto-repaired (fix-memory-frontmatter.sh)"
    else
      echo "   ⚠️  Repair attempted but validation still failing: $(grep -m1 . /tmp/memory_revalidation.log)"
      ((ISSUES++))
    fi
  else
    echo "   ⚠️  Auto-repair failed: $(grep -m1 . /tmp/memory_fix.log)"
    ((ISSUES++))
  fi
fi

# 6. Cron job validation (only on systems with crontab)
if command -v crontab &> /dev/null; then
  if bash "$WORKSPACE_DIR/scripts/validate-all-cron-jobs.sh" > /tmp/cron_validation.log 2>&1; then
    echo "✅ All automation cron jobs healthy"
  else
    echo "⚠️  Cron job issues detected"
    ((ISSUES++))
  fi
fi

# 7. WooCommerce API key rotation freshness
if bash "$WORKSPACE_DIR/scripts/check_woocommerce_key_age.sh" > /tmp/wookey_check.log 2>&1; then
  echo "✅ WooCommerce API keys fresh"
else
  echo "⚠️  WooCommerce API key rotation check failed:"
  echo "    $(head -1 /tmp/wookey_check.log)"
  ((ISSUES++))
fi

# 8. Disk space on root partition (wires in check_disk_space.sh)
#    Exit codes: 0=ok, 2=warning (>=WARN_THRESHOLD), 1=critical/unknown.
#    Distinguish warning from critical so a 90-94% disk is not reported as OK.
bash "$WORKSPACE_DIR/scripts/check_disk_space.sh" > /tmp/disk_check.log 2>&1
DISK_RC=$?
if [ "$DISK_RC" -eq 0 ]; then
  echo "✅ Disk space OK"
elif [ "$DISK_RC" -eq 2 ]; then
  echo "⚠️  Disk space WARNING (see /tmp/disk_check.log):"
  echo "    $(head -1 /tmp/disk_check.log)"
  ((ISSUES++))
else
  echo "⚠️  Disk space issue (see /tmp/disk_check.log):"
  echo "    $(head -1 /tmp/disk_check.log)"
  ((ISSUES++))
fi

# 9. Daily scheduled snapshot freshness (label-aware, not file-count-based)
#    validate_backup.sh counts ANY snapshot from the last 24h — including ones
#    the validation runs trigger themselves (validate_critical_rules.sh fires
#    a "Critical rules validation" snapshot on every run), so a dead daily
#    schedule stayed invisible. This only accepts snapshots labeled
#    daily_auto_snapshot — the exact label HOST-SETUP-CRON.sh's 02:30 UTC job
#    passes to snapshot.sh — so validation/manual snapshots can't mask it.
SNAPSHOT_DIR="/home/node/.openclaw/backups"
if [ ! -d "$SNAPSHOT_DIR" ]; then
  echo "⚠️  Snapshot dir missing: $SNAPSHOT_DIR"
  ((ISSUES++))
else
  RECENT_DAILY=$(find "$SNAPSHOT_DIR" -name 'snapshot-*-daily_auto_snapshot.tar.gz' -mmin -1560 2>/dev/null | head -n1)
  if [ -n "$RECENT_DAILY" ]; then
    echo "✅ Daily snapshot fresh: $(basename "$RECENT_DAILY")"
  else
    LAST_DAILY=$(find "$SNAPSHOT_DIR" -name 'snapshot-*-daily_auto_snapshot.tar.gz' 2>/dev/null | sort | tail -n1)
    if [ -n "$LAST_DAILY" ]; then
      AGE_H=$(( ($(date -u +%s) - $(stat -c %Y "$LAST_DAILY")) / 3600 ))
      echo "⚠️  Last daily_auto_snapshot is ${AGE_H}h old — the daily 02:30 UTC"
      echo "    snapshot job is NOT running (validation snapshots don't count)."
    else
      echo "⚠️  No daily_auto_snapshot ever created — daily 02:30 UTC snapshot"
      echo "    job is NOT running."
    fi
    echo "    Fix options: run HOST-SETUP-CRON.sh on the VPS host, or add an OpenClaw"
    echo "    cron job (isolated agentTurn) running: scripts/snapshot.sh daily_auto_snapshot"
    ((ISSUES++))
  fi
fi

# 10. Open blockers waiting on user/external action (memory/blockers.md)
#     Fresh blockers (<24h) are informational only; stale ones (>24h) count as
#     an issue so blocked work (e.g. awaiting Volker's fixes) stays visible
#     instead of silently rotting in daily memory files.
BLOCKERS_RC=0
bash "$WORKSPACE_DIR/scripts/check-blockers.sh" > /tmp/blockers_check.log 2>&1 || BLOCKERS_RC=$?
if [ "$BLOCKERS_RC" -eq 0 ]; then
  if grep -q "Open blocker" /tmp/blockers_check.log; then
    echo "ℹ️  Fresh open blocker(s) (<24h):"
    head -5 /tmp/blockers_check.log | sed 's/^/    /'
  else
    echo "✅ No open blockers"
  fi
else
  echo "⚠️  Stale open blocker(s) (>24h) — needs attention:"
  head -5 /tmp/blockers_check.log | sed 's/^/    /'
  ((ISSUES++))
fi

# 11. Telegram bot token validity (wires in check_telegram_token.sh)
#     Outbound Telegram sends (nudges, notifications) fail with 401 when a bot
#     token in openclaw.json is revoked/stale — previously only discovered
#     during nudge attempts, days late. getMe is a free, side-effect-free probe.
if bash "$WORKSPACE_DIR/scripts/check_telegram_token.sh" > /tmp/telegram_check.log 2>&1; then
  echo "✅ Telegram bot tokens valid"
else
  echo "⚠️  Telegram bot token check failed:"
  head -6 /tmp/telegram_check.log | sed 's/^/    /'
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
