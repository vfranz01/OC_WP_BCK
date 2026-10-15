#!/bin/bash
# nudge-blockers.sh — Print ready-to-send reminders for stale user-blockers.
#
# Problem: check-blockers.sh flags stale blockers in *internal* logs, but the
# person who can unblock them (Volker) never sees them unless a session goes
# out of its way to read blockers.md. This script turns stale
# "waiting_on: user" blockers into short, copy-paste reminder texts.
#
# Usage:
#   bash scripts/nudge-blockers.sh           # nudges for blockers >48h old
#   bash scripts/nudge-blockers.sh --days N  # custom staleness threshold (hours)
#   bash scripts/nudge-blockers.sh --all     # include fresh blockers too
#   bash scripts/nudge-blockers.sh --record sent|failed
#                                            # mark today's run result for all
#                                            # qualifying blockers (delivery
#                                            # outcome), then exit
#
# Output: one "NUDGE" block per qualifying blocker with a suggested message.
# Dedup: successful sends are remembered in memory/nudge-state.log; a blocker
# nudged successfully today is not printed again ("max 1 nudge/day" enforced
# mechanically). Failed attempts are NOT deduped — they keep reappearing so
# delivery gets retried (e.g. Telegram 401 until token is fixed).
# Exit codes:
#   0 = nothing to nudge (or everything already delivered today)
#   1 = at least one nudge printed (caller can send them)
#
# Used by daily-improve-context.sh (section: Blocker nudges).

set -uo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLOCKERS_FILE="$WORKSPACE_DIR/memory/blockers.md"
STATE_FILE="$WORKSPACE_DIR/memory/nudge-state.log"   # lines: <UTC date>\t<sent|failed>\t<title prefix>
THRESHOLD_HOURS=48
INCLUDE_ALL=0
RECORD=""

while [ $# -gt 0 ]; do
  case "$1" in
    --days) THRESHOLD_HOURS="${2:-48}"; shift 2 ;;
    --all) INCLUDE_ALL=1; shift ;;
    --record)
      case "${2:-}" in sent|failed) RECORD="$2" ;; *) echo "--record needs 'sent' or 'failed'" >&2; exit 2 ;; esac
      shift 2 ;;
    *) shift ;;
  esac
done
case "$THRESHOLD_HOURS" in (*[!0-9]*|'') THRESHOLD_HOURS=48 ;; esac

[ -f "$BLOCKERS_FILE" ] || { echo "✅ No blockers tracked"; exit 0; }

NOW=$(date -u +%s)
TODAY=$(date -u +%Y-%m-%d)
NUDGE_COUNT=0
SKIPPED_TODAY=0
CURRENT_TITLE=""; CURRENT_DATE=""; CURRENT_STATUS=""; CURRENT_WAITING=""; CURRENT_NEXT=""

# Normalize a title to a stable state-key prefix (strip markdown, limit length).
state_key() {
  printf '%s' "$1" | tr -d '\t' | cut -c1-60
}

already_sent_today() {
  local key; key=$(state_key "$1")
  [ -f "$STATE_FILE" ] && grep -qF "$(printf '%s\tsent\t%s' "$TODAY" "$key")" "$STATE_FILE"
}

record_result() {
  local key; key=$(state_key "$1")
  printf '%s\t%s\t%s\n' "$TODAY" "$RECORD" "$key" >> "$STATE_FILE"
}

flush() {
  if [ -n "$CURRENT_TITLE" ] && [ "$CURRENT_STATUS" = "open" ]; then
    local age_h=-1
    if [ -n "$CURRENT_DATE" ]; then
      age_h=$(( (NOW - $(date -u -d "$CURRENT_DATE" +%s 2>/dev/null || echo "$NOW")) / 3600 ))
    fi
    if [ "$age_h" -ge "$THRESHOLD_HOURS" ] || { [ "$INCLUDE_ALL" = 1 ] && [ "$age_h" -ge 0 ]; }; then
      if [ -n "$RECORD" ]; then
        record_result "$CURRENT_TITLE"
        NUDGE_COUNT=$((NUDGE_COUNT + 1))
        echo "── RECORDED ($RECORD, age ${age_h}h) ${CURRENT_TITLE} ──"
      elif already_sent_today "$CURRENT_TITLE"; then
        SKIPPED_TODAY=$((SKIPPED_TODAY + 1))
      else
        NUDGE_COUNT=$((NUDGE_COUNT + 1))
        echo "── NUDGE (age ${age_h}h, waiting_on: ${CURRENT_WAITING:-?}) ──"
        echo "TO: Volker"
        echo "MSG: ⏳ Reminder: blocker still open (${age_h}h): ${CURRENT_TITLE}"
        echo "     Next action: ${CURRENT_NEXT:-<unspecified>}"
        echo
      fi
    fi
  fi
  CURRENT_TITLE=""; CURRENT_DATE=""; CURRENT_STATUS=""; CURRENT_WAITING=""; CURRENT_NEXT=""
}

# Skip the HTML comment block (formatting template) like check-blockers.sh does.
SKIP=0
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in "<!--"*) SKIP=1; continue ;; "-->"*) SKIP=0; continue ;; esac
  [ "$SKIP" = 1 ] && continue
  case "$line" in
    "## "*)
      flush
      CURRENT_TITLE="${line#\#\# }"
      CURRENT_DATE=$(printf '%s' "$CURRENT_TITLE" | grep -oE '^20[0-9]{2}-[0-9]{2}-[0-9]{2}' || true)
      ;;
    *"status:"*) CURRENT_STATUS=$(printf '%s' "$line" | sed 's/.*status:[[:space:]]*//' | tr -d ' `*_') ;;
    *"waiting_on:"*) CURRENT_WAITING=$(printf '%s' "$line" | sed 's/.*waiting_on:[[:space:]]*//' | tr -d ' `*_') ;;
    *"next:"*) CURRENT_NEXT=$(printf '%s' "$line" | sed 's/.*next:[[:space:]]*//' | cut -c1-200) ;;
  esac
done < "$BLOCKERS_FILE"
flush

if [ "$NUDGE_COUNT" -gt 0 ]; then
  if [ -n "$RECORD" ]; then
    echo "✅ Recorded '$RECORD' for $NUDGE_COUNT blocker(s)"
    exit 0
  fi
  [ "$SKIPPED_TODAY" -gt 0 ] && echo "ℹ️  $SKIPPED_TODAY blocker(s) already nudged successfully today (dedup)" >&2
  exit 1
fi
[ "$SKIPPED_TODAY" -gt 0 ] && echo "ℹ️  $SKIPPED_TODAY blocker(s) already nudged successfully today — nothing to send"
exit 0
