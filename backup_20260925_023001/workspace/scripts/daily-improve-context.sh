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
