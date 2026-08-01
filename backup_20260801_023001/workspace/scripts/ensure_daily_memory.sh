#!/bin/bash

# Ensure daily memory files exist.
# If today's or yesterday's memory file is missing, create it.

MEMORY_DIR="/home/node/.openclaw/workspace/memory"
TODAY=$(date -u +"%Y-%m-%d")
YESTERDAY=$(date -u -d "yesterday" +"%Y-%m-%d")

# Ensure the memory directory exists
mkdir -p "$MEMORY_DIR"

# Check and create today's file if missing
if [ ! -f "$MEMORY_DIR/$TODAY.md" ]; then
    echo "Creating missing daily memory file: $MEMORY_DIR/$TODAY.md"
    /home/node/.openclaw/workspace/scripts/create_daily_memory_file.sh "$TODAY"
fi

# Check and create yesterday's file if missing
if [ ! -f "$MEMORY_DIR/$YESTERDAY.md" ]; then
    echo "Creating missing daily memory file: $MEMORY_DIR/$YESTERDAY.md"
    /home/node/.openclaw/workspace/scripts/create_daily_memory_file.sh "$YESTERDAY"
fi

echo "Daily memory file check complete."
exit 0
