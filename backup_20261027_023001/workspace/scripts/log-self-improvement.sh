#!/usr/bin/env bash
# log-self-improvement.sh
# Appends a dated entry to memory/self-improvement-log.md so daily workflow
# improvements are traceable. Part of the Daily Self-Improvement routine.
#
# Usage:
#   bash scripts/log-self-improvement.sh "Short title" "What was changed"
#   echo "multi
#   line" | bash scripts/log-self-improvement.sh "Title"

set -euo pipefail

cd "$(dirname "$0")/.."
LOG="memory/self-improvement-log.md"
TODAY="$(date -u +%Y-%m-%d)"

title="${1:-Daily self-improvement}"
# body from $2 or stdin
if [ -n "${2:-}" ]; then
  body="$2"
else
  body="$(cat)"
fi

if [ ! -f "$LOG" ]; then
  cat > "$LOG" <<'EOF'
# Self-Improvement Log

Dated, traceable record of workflow improvements made during the
Daily Self-Improvement routine. Newest entries at the bottom.

EOF
fi


# Print safely without shell evaluation
printf "\n## %s — %s\n\n%s\n" "$TODAY" "$title" "$body" >> "$LOG"

echo "Logged to $LOG"

# Keep AGENTS.md's "Recent Improvements" list in lock-step with the log.
# Writing a log entry is exactly what makes the durable AGENTS.md list stale,
# so without this the drift guard (sync-agents-improvements.sh --check, wired
# into daily-improve-context.sh) flagged drift EVERY morning: the 2026-10-07
# fix synced the list, then logging that same fix immediately re-staled it.
# Best-effort — never fail the log write if the sync is unavailable.
SYNC="$(dirname "$0")/sync-agents-improvements.sh"
if [ -f "$SYNC" ]; then
  if bash "$SYNC" >/dev/null 2>&1; then
    echo "Synced AGENTS.md 'Recent Improvements'"
  else
    echo "⚠️  AGENTS.md sync skipped (run sync-agents-improvements.sh to inspect)" >&2
  fi
fi