#!/bin/bash
# check-blockers.sh — Surface open blockers from memory/blockers.md
#
# Why: Items waiting on Volker/external fixes used to live only in daily
# memory files and silently went stale (e.g. 2026-09-20 ecomunivers post
# blocked on WP keys + Cloudflare SSL). This makes them a first-class,
# heartbeat-visible state.
#
# File format (memory/blockers.md), one block per entry:
#   ## YYYY-MM-DD — <short title>
#   - status: open        (or: resolved)
#   - waiting_on: user|external|mux
#   - next: <exact next action>
#
# Exit codes:
#   0 = no open blockers (or only fresh ones, <24h — informational)
#   1 = at least one open blocker older than 24h

WORKSPACE_DIR="/home/node/.openclaw/workspace"
BLOCKERS_FILE="$WORKSPACE_DIR/memory/blockers.md"

OPEN_COUNT=0
STALE_COUNT=0
CURRENT_TITLE=""
CURRENT_STATUS=""
CURRENT_DATE=""

flush() {
  if [ -n "$CURRENT_TITLE" ] && [ "$CURRENT_STATUS" = "open" ]; then
    OPEN_COUNT=$((OPEN_COUNT + 1))
    if [ -n "$CURRENT_DATE" ]; then
      AGE_DAYS=$(( ($(date -u +%s) - $(date -u -d "$CURRENT_DATE" +%s)) / 86400 ))
    else
      AGE_DAYS=-1
    fi
    if [ "$AGE_DAYS" -ge 1 ]; then
      STALE_COUNT=$((STALE_COUNT + 1))
      echo "⚠️  Open blocker (${AGE_DAYS}d old): $CURRENT_TITLE"
    elif [ "$AGE_DAYS" -eq 0 ]; then
      echo "ℹ️  Open blocker (today): $CURRENT_TITLE"
    else
      echo "ℹ️  Open blocker (no/invalid date): $CURRENT_TITLE"
    fi
  fi
  CURRENT_TITLE=""
  CURRENT_STATUS=""
  CURRENT_DATE=""
}

if [ ! -f "$BLOCKERS_FILE" ]; then
  echo "✅ No blockers tracked (memory/blockers.md absent)"
  exit 0
fi

while IFS= read -r line; do
  case "$line" in
    "## "*)
      flush
      CURRENT_TITLE="${line#\#\# }"
      CURRENT_DATE=$(printf '%s' "$CURRENT_TITLE" | grep -oE '^20[0-9]{2}-[0-9]{2}-[0-9]{2}' || true)
      CURRENT_STATUS=""
      ;;
    *"status:"*)
      CURRENT_STATUS=$(printf '%s' "$line" | sed 's/.*status:[[:space:]]*//' | tr -d ' `*_')
      ;;
  esac
done < "$BLOCKERS_FILE"
flush

if [ "$STALE_COUNT" -gt 0 ]; then
  echo "→ Resolve or update status in $BLOCKERS_FILE (set 'status: resolved' when done)."
  exit 1
fi

if [ "$OPEN_COUNT" -eq 0 ]; then
  echo "✅ No open blockers"
else
  echo "→ Fresh blocker(s) only; re-check tomorrow."
fi
exit 0