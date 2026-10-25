#!/bin/bash
# daily-improve-context.sh
# One-shot context brief for the daily self-improvement cron (and any session
# looking for "what should I improve today?").
#
# Prints:
#   1. Recent self-improvement entries (titles + dates) so the same fix is
#      not repeated.
#   2. Open blockers (stale ones first) that need user/external action, plus
#      nudge state and drafts waiting in outbox/.
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
# Delivery + outcome recording is a single command (no manual --record step):
#   bash scripts/send-blocker-nudges.sh
# This brief only *prints* them for context; the wrapper is what actually sends.
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
      echo "  Reminders that failed stay queued — deliver the backlog after the fix:"
      echo "  bash scripts/send-blocker-nudges.sh --flush"
    fi
  fi
fi

# 2c-bis. Undelivered reminder queue (memory/undelivered-nudges.md)
# Sending + recording is now one command; text that could not be delivered is
# persisted verbatim instead of being rebuilt from blockers.md later.
QUEUED=$( [ -f memory/undelivered-nudges.md ] && grep -c '^## ' memory/undelivered-nudges.md 2>/dev/null || echo 0 )
if [ "${QUEUED:-0}" -gt 0 ]; then
  echo
  echo "── Undelivered nudge queue: $QUEUED item(s) ──"
  grep '^## ' memory/undelivered-nudges.md | tail -3 | sed 's/^## /   • /'
  echo "→ Flush: auto-drained on outage recovery (check_telegram_token.sh), or manually:"
  echo "  bash scripts/flush-all-queues.sh   # preflights the token, sends nothing if still dead"
fi

# 2c-ter. Generic undelivered notification queue (memory/undelivered-notifications.md)
# telegram-send.sh now persists ANY failed alert there (backup, blog, security),
# not just blocker nudges. Surface the count so the backlog is visible in the
# brief instead of only when someone remembers to run --queue-status.
NOTIF_QUEUE_OUT=$(python3 scripts/notify-queue.py status 2>/dev/null || true)
if echo "$NOTIF_QUEUE_OUT" | grep -q '^Undelivered notifications:'; then
  NOTIF_COUNT=$(echo "$NOTIF_QUEUE_OUT" | sed -n 's/^Undelivered notifications: //p')
  echo
  echo "── Undelivered notification queue: $NOTIF_COUNT item(s) ──"
  echo "$NOTIF_QUEUE_OUT" | grep '^  • ' | tail -3
  echo "→ Both queues at once (nudges first, then notifications):"
  echo "  bash scripts/flush-all-queues.sh   # preflights the token, sends nothing if still dead"
fi

# 2d. Outbox / pending drafts (drafts waiting for publication)
# Surfaces content that has slipped off the blockers list, so drafts are not
# silently forgotten while WP access is unavailable. Informational only.
OUTBOX_OUT=$(bash scripts/check-outbox.sh --quiet 2>&1 || true)
if [ -n "$OUTBOX_OUT" ]; then
  echo
  echo "--- Outbox / pending drafts ---"
  echo "$OUTBOX_OUT"
fi

# 3. Git dirtiness
echo
echo "--- Git state ---"
DIRTY=$(git status --porcelain 2>/dev/null | wc -l)
echo "Uncommitted/untracked files: $DIRTY"
git log --oneline -1 2>/dev/null || echo "(no commits)"

# 4. Failing health checks (top improvement candidates)
#    Include the 🚨 escalation line (e.g. Telegram outage day N) — it is
#    indented inside the health summary, so a bare '^⚠️|^❌' grep missed it
#    and the most severe, longest-running failure never reached the brief.
echo
echo "--- health-quick-check failing lines ---"
if bash scripts/health-quick-check.sh >/tmp/improve_health.log 2>&1; then
  echo "(all healthy)"
else
  grep -E '^⚠️|^❌|🚨' /tmp/improve_health.log | head -8
fi

# 4b. Script docs drift (scripts/README.md behind the code)
#     Catches new scripts that were never documented — the README silently
#     drifted ~5 months and hid 20 scripts before this guard existed.
#     Informational only; never fails the brief.
DOC_DRIFT=$(bash scripts/check-scripts-doc.sh 2>&1 || true)
if [ -n "$DOC_DRIFT" ] && ! printf '%s' "$DOC_DRIFT" | grep -q '^✅'; then
  echo
  echo "--- Script docs drift ---"
  printf '%s\n' "$DOC_DRIFT"
fi

# 4c. AGENTS.md "Recent Improvements" drift (list behind the self-improvement log)
#     The list is the durable, every-session-visible summary of recent
#     automation, but it was hand-maintained and drifted (frozen at 2026-09-28
#     while newer log entries existed). sync-agents-improvements.sh --check is
#     a pure read; the daily agent can then run the script without --check to
#     refresh it. Informational only; never fails the brief.
AGENTS_DRIFT=$(bash scripts/sync-agents-improvements.sh --check 2>&1 || true)
if ! printf '%s' "$AGENTS_DRIFT" | grep -q '^✅'; then
  echo
  echo "--- AGENTS.md improvements drift ---"
  printf '%s\n' "$AGENTS_DRIFT"
  echo "→ refresh: bash scripts/sync-agents-improvements.sh"
fi

# 5. Recent open errors
echo
echo "--- Blocked-services probe ---"
if [ -f scripts/check-blocked-services.sh ]; then
  bash scripts/check-blocked-services.sh || true
else
  echo "(check-blocked-services.sh missing)"
fi

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
