#!/bin/bash

# Fail loudly if a daily file cannot be created. This script is a session
# prerequisite; silently continuing would leave later checks operating without
# the memory file they believe they created.
set -euo pipefail

# Ensure daily memory files exist.
# If today's or yesterday's memory file is missing, create it.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MEMORY_DIR="$WORKSPACE_DIR/memory"
CREATE_SCRIPT="$SCRIPT_DIR/create_daily_memory_file.sh"
TODAY=$(date -u +"%Y-%m-%d")
YESTERDAY=$(date -u -d "yesterday" +"%Y-%m-%d")

# Ensure the memory directory exists
mkdir -p "$MEMORY_DIR"

# Check and create today's file if missing
if [ ! -f "$MEMORY_DIR/$TODAY.md" ]; then
    echo "Creating missing daily memory file: $MEMORY_DIR/$TODAY.md"
    "$CREATE_SCRIPT" "$TODAY"
fi

# Check and create yesterday's file if missing
if [ ! -f "$MEMORY_DIR/$YESTERDAY.md" ]; then
    echo "Creating missing daily memory file: $MEMORY_DIR/$YESTERDAY.md"
    "$CREATE_SCRIPT" "$YESTERDAY"
fi

echo "Daily memory file check complete."

# Stopgap: keep the daily snapshot chain alive while the real host cron job is
# not installed (see memory/self-improvement-log.md 2026-09-12/13). Runs at
# most once per 23h window; non-fatal by design. Executed after the daily file
# exists so a snapshot failure never blocks memory bootstrap.
"$SCRIPT_DIR/snapshot_stopgap.sh" --quiet || true

exit 0
