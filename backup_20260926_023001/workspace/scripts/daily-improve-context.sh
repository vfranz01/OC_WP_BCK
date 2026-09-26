#!/bin/bash
# daily-improve-context.sh
# One-shot context brief for the daily self-improvement cron (and any session
# looking for "what should I improve today?").
#
# Prints:
#   1. Recent self-improvement entries (titles + dates) so the same fix is
#      not repeated.
#   2. Open blockers (stale ones first) that need user/external action.
#   3. Git workspace dirtiness (uncommitted changes that may already contain
#      improvements, or signal an interrupted job).
#   4. Currently failing health-quick-check lines (the top improvement
#      candidates).
#   5. Recent open error-log entries from .learnings/ERRORS.md.
#
# Usage: bash scripts/daily-improve-context.sh
# Exit code: always 0 (informational brief, never fails a cron run).

set -uo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WORKSPACE_DIR" || exit 0

echo "=== Daily Improve Context ($(date -u '+%Y-%m-%d %H:%M UTC')) ==="

# 1. Recent self-improvement entries (avoid repeating)
echo
echo "--- Recent self-improvements (last 6 entries) ---"
grep -E '^## 2026' memory/self-improvement-log.md 2>/dev/null | tail -6 || echo "(none found)"

# 2. Open blockers
# 2b. Blocker nudges (ready to send to user when stale >48h)
echo
echo "--- Open blockers ---"
if [ -f memory/blockers.md ]; then
  awk '/<!--/{skip=1} /-->/{skip=0; next} !skip' memory/blockers.md \
    | grep -E 'status: (open|resolved)$|waiting_on: [a-z ]+$|next: ' | head -9
  BLOCKER_TITLES=$(awk '/<!--/{skip=1} /-->/{skip=0; next} !skip' memory/blockers.md 2>/dev/null | grep '^## ' | tail -3)
  [ -n "$BLOCKER_TITLES" ] && echo "$BLOCKER_TITLES"
else
  echo "(no blockers.md)"
fi

# 2b. Blocker nudges — stale user-blockers (>48h) as ready-to-send reminders.
# If any are printed, the daily agent should deliver them to Volker via
# Telegram (message tool) unless one was already sent for this blocker today.
if bash scripts/nudge-blockers.sh > /tmp/blocker_nudges.txt 2>&1; then
  :  # nothing stale, no output needed
else
  echo
  echo "--- Blocker nudges (stale user-blockers, deliver to Volker) ---"
  cat /tmp/blocker_nudges.txt

  # 2c. Today's recorded nudge outcomes (memory/nudge-state.log: date<TAB>outcome<TAB>blocker)
  # Surfaces already-attempted sends so the agent does not blindly re-attempt a
  # delivery that already failed today for a known reason (e.g. 401 bot token).
  NUDGE_TODAY=$(awk -F'\t' -v d="$(date -u +%Y-%m-%d)" '$1==d' memory/nudge-state.log 2>/dev/null | tail -3)
  if [ -n "$NUDGE_TODAY" ]; then
    echo
    echo "── Nudge state today ($(date -u +%Y-%m-%d)) ──"
    echo "$NUDGE_TODAY"
    if echo "$NUDGE_TODAY" | awk -F'\t' '$2=="failed"' | grep -q .; then
      echo "→ A nudge send already FAILED today. Re-attempt only after fixing the cause:"
      echo "  bash scripts/check_telegram_token.sh   # if tokens are 401, regen via @BotFather first"
      echo "  Otherwise record the outcome without sending: bash scripts/nudge-blockers.sh --record failed"
    fi
  fi
fi

# 3. Git dirtiness
echo
echo "--- Git state ---"
DIRTY=$(git status --porcelain 2>/dev/null | wc -l)
echo "Uncommitted/untracked files: $DIRTY"
git log --oneline -1 2>/dev/null || echo "(no commits)"

# 4. Failing health checks (top improvement candidates)
echo
echo "--- health-quick-check failing lines ---"
if bash scripts/health-quick-check.sh >/tmp/improve_health.log 2>&1; then
  echo "(all healthy)"
else
  grep -E '^⚠️|^❌' /tmp/improve_health.log | head -8
fi

# 5. Recent open errors
echo
echo "--- Recent open errors (.learnings/ERRORS.md) ---"
if [ -f .learnings/ERRORS.md ]; then
  awk '/^\*\*Status\*\*:/{print $NF}' .learnings/ERRORS.md 2>/dev/null | sort | uniq -c
  OPEN_ERRS=$(grep -cE '^\*\*Status\*\*: open' .learnings/ERRORS.md 2>/dev/null)
  echo "Open error entries: ${OPEN_ERRS:-0}"
else
  echo "(no ERRORS.md)"
fi

echo
echo "=== End context brief ==="
exit 0
