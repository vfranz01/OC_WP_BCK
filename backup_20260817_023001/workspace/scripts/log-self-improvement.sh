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

{
  echo ""
  echo "## $TODAY — $title"
  echo ""
  echo "$body"
} >> "$LOG"

echo "Logged to $LOG"