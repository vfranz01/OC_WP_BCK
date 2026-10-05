#!/bin/bash
# Quick Health Check — Fast status probe for heartbeat use
# Returns 0 = OK, non-zero = issues detected
# Use: bash health-quick-check.sh && echo "All good" || echo "Check logs"

WORKSPACE_DIR="/home/node/.openclaw/workspace"
ISSUES=0
INFO_ISSUES=0

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

# 4. Daily memory files present (self-healing)
#    Existence-based, not mtime-based: previously this only looked at the newest
#    20*.md mtime, so a *missing today* file stayed invisible as long as any
#    recent log existed (observed 2026-10-03: 10-02 and 10-03 both absent while
#    the check reported ✅). AGENTS.md requires ensure_daily_memory.sh every
#    session, but nothing enforced it — so detect and self-heal here.
MEM_DIR="$WORKSPACE_DIR/memory"
TODAY_MEM=$(date -u +%Y-%m-%d)
YESTERDAY_MEM=$(date -u -d "yesterday" +%Y-%m-%d)
MISSING_MEM=()
for d in "$TODAY_MEM" "$YESTERDAY_MEM"; do
  [ -f "$MEM_DIR/$d.md" ] || MISSING_MEM+=("$d")
done
if [ ${#MISSING_MEM[@]} -eq 0 ]; then
  echo "✅ Daily memory files present (today + yesterday)"
else
  echo "🔧 Missing daily memory file(s): ${MISSING_MEM[*]} — self-healing via ensure_daily_memory.sh"
  bash "$WORKSPACE_DIR/scripts/ensure_daily_memory.sh" > /tmp/ensure_mem.log 2>&1 || true
  STILL_MISSING=()
  for d in "${MISSING_MEM[@]}"; do
    [ -f "$MEM_DIR/$d.md" ] || STILL_MISSING+=("$d")
  done
  if [ ${#STILL_MISSING[@]} -eq 0 ]; then
    echo "   ✅ Auto-repaired (ensure_daily_memory.sh)"
    ((INFO_ISSUES++))
  else
    echo "   ⚠️  Still missing after repair: ${STILL_MISSING[*]} (see /tmp/ensure_mem.log)"
    ((ISSUES++))
  fi
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
#
#    Self-heal (2026-09-29): before evaluating staleness, run
#    snapshot_stopgap.sh (idempotent, flock-guarded). This check fires more
#    often than daily-status-summary.sh (its only stopgap caller), so a stale
#    chain now gets repaired here instead of only being reported. If the
#    stopgap fails, the staleness alert below still fires — no silent
#    failure masking.
SNAPSHOT_DIR="/home/node/.openclaw/backups"
if [ ! -d "$SNAPSHOT_DIR" ]; then
  echo "⚠️  Snapshot dir missing: $SNAPSHOT_DIR"
  ((ISSUES++))
else
  # Attempt self-heal first; cheap no-op when a fresh snapshot exists.
  STOPGAP_OUT=$(bash "$SCRIPT_DIR/snapshot_stopgap.sh" --quiet 2>&1)
  if [ -n "$STOPGAP_OUT" ]; then
    echo "🔧 Snapshot self-heal via snapshot_stopgap: $STOPGAP_OUT"
  fi
  RECENT_DAILY=$(find "$SNAPSHOT_DIR" -name 'snapshot-*-daily_auto_snapshot.tar.gz' -mmin -1560 2>/dev/null | head -n1)
  if [ -n "$RECENT_DAILY" ]; then
    echo "✅ Daily snapshot fresh: $(basename "$RECENT_DAILY")"
  else
    LAST_DAILY=$(find "$SNAPSHOT_DIR" -name 'snapshot-*-daily_auto_snapshot.tar.gz' 2>/dev/null | sort | tail -n1)
    if [ -n "$LAST_DAILY" ]; then
      AGE_H=$(( ($(date -u +%s) - $(stat -c %Y "$LAST_DAILY")) / 3600 ))
      echo "⚠️  Last local daily_auto_snapshot tar is ${AGE_H}h old (validation snapshots don't count)."
    else
      echo "⚠️  No daily_auto_snapshot tar ever created — local snapshot chain empty."
    fi
    # A stale local tar alone no longer means the backup pipeline is dead:
    # the host 02:30 UTC GitHub job (backup_github_sync.sh) may be running
    # fine while the in-container snapshot step fails silently (e.g. DOCKER_CMD
    # host-cron issue, 2026-09-26). Off-machine backup is the layer that
    # actually protects against container loss, so verify it before alarming.
    GH_FRESH=0
    GH_LOG="/home/node/.openclaw/logs/backup.log"
    if [ -f "$GH_LOG" ] \
       && [ $(( ($(date -u +%s) - $(stat -c %Y "$GH_LOG")) / 60 )) -lt 1560 ] \
       && [ "$(tail -n1 "$GH_LOG")" = "Backup completed successfully" ]; then
      GH_FRESH=1
      GH_AGE_H=$(( ($(date -u +%s) - $(stat -c %Y "$GH_LOG")) / 3600 ))
      echo "    ℹ️  Off-machine GitHub backup IS fresh (${GH_AGE_H}h ago, backup.log) —"
      echo "       data is safe; only the local tar chain is stale."
      echo "    Local chain fix: bash scripts/snapshot_stopgap.sh (runs once per 23h window)."
    else
      echo "    ⚠️  Off-machine GitHub backup also stale/failed (backup.log mtime or"
      echo "       last line) — the whole 02:30 UTC backup pipeline is down."
      echo "    Fix options: run HOST-SETUP-CRON.sh on the VPS host, or add an OpenClaw"
      echo "    cron job (isolated agentTurn) running: scripts/snapshot.sh daily_auto_snapshot"
    fi
    # Fresh off-machine GitHub backup → downgrade to informational
    if [ "$GH_FRESH" -eq 0 ]; then
      ((ISSUES++))
    else
      ((INFO_ISSUES++))
    fi
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

# 12. Memory index freshness (self-healing)
#     memory/index.md is the auto-generated navigation index for the daily logs.
#     Its canonical refresh lives in daily-heartbeat-routine.sh, but that
#     routine is not scheduled on this host, so the index silently drifted stale
#     (last entry 2026-09-14 while 180+ daily logs existed). daily-status-summary.sh
#     also refreshes it — but *that* script has the same single-caller problem.
#     health-quick-check.sh runs on every daily agent pass, so refresh here too
#     (idempotent: a same-day index is a no-op, keeping the other callers cheap).
INDEX_FILE="$WORKSPACE_DIR/memory/index.md"
if [ -f "$INDEX_FILE" ]; then
  INDEX_DATE=$(grep -m1 '^date: ' "$INDEX_FILE" 2>/dev/null | sed 's/^date:[[:space:]]*//')
  TODAY_UTC=$(date -u +%Y-%m-%d)
  if [ "$INDEX_DATE" = "$TODAY_UTC" ]; then
    echo "✅ Memory index current ($INDEX_DATE)"
  elif python3 "$WORKSPACE_DIR/scripts/update-memory-index.py" >/dev/null 2>&1; then
    echo "🔧 Memory index self-heal: refreshed stale index (was ${INDEX_DATE:-unknown}, now $TODAY_UTC)"
    ((INFO_ISSUES++))
  else
    echo "⚠️  Memory index stale (${INDEX_DATE:-unknown}) and refresh failed (update-memory-index.py)"
    ((ISSUES++))
  fi
else
  echo "⚠️  Memory index missing: $INDEX_FILE"
  ((ISSUES++))
fi

# 13. Workspace git checkpoint (self-healing)
#     AGENTS.md says "commit and push your own changes" is valid proactive work,
#     but on this host the daily self-improvement agent is the ONLY routine
#     committer (host cron was never installed). Between runs, doc/memory edits
#     pile up uncommitted — invisible to git history and the git-based backup
#     chain, and lost if the container dies mid-day. This checkpoints the
#     allow-listed workspace changes via commit-workspace.sh (idempotent: no-op
#     when clean; never pushes; refuses secrets/.pyc by construction).
#
#     Noise-aware: this health check itself (and the daily scripts it calls)
#     mutate a handful of runtime-state files on EVERY run (backup_incidents.log,
#     backup_github_sync.log, last_snapshot.txt, telegram-outage.state) plus the
#     nested backup_repo gitlink. Committing on those alone would create a commit
#     per heartbeat of pure log churn. So only trigger a checkpoint when there is
#     a *substantive* change (docs, memory knowledge, scripts, new daily logs).
#     Success is informational so a routine checkpoint doesn't flip the health
#     verdict; a refused/failed checkpoint is a real issue. Disable auto-commit
#     with HEALTH_NO_AUTOCOMMIT=1 (then it only reports dirtiness).
RUNTIME_NOISE=' (memory/backup_incidents\.log|memory/backup_github_sync\.log|memory/last_snapshot\.txt|memory/telegram-outage\.state)$'
if git -C "$WORKSPACE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  DIRTY_REAL=$(git -C "$WORKSPACE_DIR" status --porcelain -- . ':(exclude)backup_repo' 2>/dev/null \
                 | grep -vE "$RUNTIME_NOISE" | grep -c . || true)
  if [ "${DIRTY_REAL:-0}" -eq 0 ]; then
    echo "✅ Workspace git clean (no substantive changes; runtime-state churn ignored)"
  elif [ "${HEALTH_NO_AUTOCOMMIT:-0}" = "1" ]; then
    echo "ℹ️  Workspace has $DIRTY_REAL substantive uncommitted change(s) (auto-commit disabled)"
  else
    COMMIT_OUT=$(bash "$WORKSPACE_DIR/scripts/commit-workspace.sh" "chore: workspace checkpoint (health-check self-heal, $TODAY_UTC)" 2>&1)
    COMMIT_RC=$?
    if [ "$COMMIT_RC" -eq 0 ] && printf '%s' "$COMMIT_OUT" | grep -q '✅ Committed workspace changes'; then
      echo "🔧 Workspace git checkpoint: committed $DIRTY_REAL substantive pending change(s)"
      ((INFO_ISSUES++))
    elif [ "$COMMIT_RC" -eq 0 ]; then
      echo "✅ Workspace git clean (nothing substantive to checkpoint)"
    else
      echo "⚠️  Workspace git checkpoint failed (see output):"
      printf '%s\n' "$COMMIT_OUT" | grep -m3 . | sed 's/^/    /'
      ((ISSUES++))
    fi
  fi
else
  echo "ℹ️  Not a git workspace — skipping git checkpoint"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ISSUES -eq 0 ]; then
  echo "✅ All systems healthy${INFO_ISSUES:+ ($INFO_ISSUES informational)}"
  exit 0
else
  echo "⚠️  Found $ISSUES issue(s) — review logs"
  exit 1
fi
