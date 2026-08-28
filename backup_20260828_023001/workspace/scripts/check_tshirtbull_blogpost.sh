#!/bin/bash
set -euo pipefail

# Find the latest memory file for today
memory_file=$(find /home/node/.openclaw/workspace/memory/ -type f -name "$(date +%Y-%m-%d)".md 2>/dev/null | tail -n 1)

if [[ -z "$memory_file" ]]; then
  echo "No memory entry found for today. Skipping check."
  exit 0
fi

# Check if the T-ShirtBull Cron-Job has run successfully
if grep -q "T-ShirtBull" "$memory_file"; then
  echo "T-ShirtBull Cron-Job check: Success Eintrag gefunden in $memory_file"
else
  echo "T-ShirtBull Cron-Job check: Kein Eintrag gefunden in $memory_file"
fi
exit 0