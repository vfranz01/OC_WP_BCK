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
#
# Output: one "NUDGE" block per qualifying blocker with a suggested message.
# Exit codes:
#   0 = nothing to nudge
#   1 = at least one nudge printed (caller can send them)
#
# Used by daily-improve-context.sh (section: Blocker nudges).

set -uo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLOCKERS_FILE="$WORKSPACE_DIR/memory/blockers.md"
THRESHOLD_HOURS=48
INCLUDE_ALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --days) THRESHOLD_HOURS="${2:-48}"; shift 2 ;;
    --all) INCLUDE_ALL=1; shift ;;
    *) shift ;;
  esac
done
case "$THRESHOLD_HOURS" in (*[!0-9]*|'') THRESHOLD_HOURS=48 ;; esac

[ -f "$BLOCKERS_FILE" ] || { echo "✅ No blockers tracked"; exit 0; }

NOW=$(date -u +%s)
NUDGE_COUNT=0
CURRENT_TITLE=""; CURRENT_DATE=""; CURRENT_STATUS=""; CURRENT_WAITING=""; CURRENT_NEXT=""

flush() {
  if [ -n "$CURRENT_TITLE" ] && [ "$CURRENT_STATUS" = "open" ]; then
    local age_h=-1
    if [ -n "$CURRENT_DATE" ]; then
      age_h=$(( (NOW - $(date -u -d "$CURRENT_DATE" +%s 2>/dev/null || echo "$NOW")) / 3600 ))
    fi
    if [ "$age_h" -ge "$THRESHOLD_HOURS" ] || { [ "$INCLUDE_ALL" = 1 ] && [ "$age_h" -ge 0 ]; }; then
      NUDGE_COUNT=$((NUDGE_COUNT + 1))
      echo "── NUDGE (age ${age_h}h, waiting_on: ${CURRENT_WAITING:-?}) ──"
      echo "TO: Volker"
      echo "MSG: ⏳ Reminder: blocker still open (${age_h}h): ${CURRENT_TITLE}"
      echo "     Next action: ${CURRENT_NEXT:-<unspecified>}"
      echo
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
  exit 1
fi
exit 0
