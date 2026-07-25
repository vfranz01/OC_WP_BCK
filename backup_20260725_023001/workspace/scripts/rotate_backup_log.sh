#!/bin/bash

# Rotate backup_incidents.log to prevent unbounded growth
# Keeps active log under 500 lines (~50KB), archives older entries monthly
# Called by validation scripts before appending new entries

LOG_FILE="/home/node/.openclaw/workspace/memory/backup_incidents.log"
ARCHIVE_DIR="/home/node/.openclaw/workspace/memory/backup_logs"
MAX_ACTIVE_LINES=500

# Create archive directory if needed
mkdir -p "$ARCHIVE_DIR"

# Check if log file exists and exceeds threshold
if [ -f "$LOG_FILE" ]; then
    LINE_COUNT=$(wc -l < "$LOG_FILE")
    
    if [ "$LINE_COUNT" -gt "$MAX_ACTIVE_LINES" ]; then
        # Archive the log with timestamp
        ARCHIVE_NAME="backup_incidents-$(date +%Y%m%d-%H%M%S).log"
        mv "$LOG_FILE" "$ARCHIVE_DIR/$ARCHIVE_NAME"
        
        # Create fresh log file
        touch "$LOG_FILE"
        chmod 644 "$LOG_FILE"
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Log rotated. Archived: $ARCHIVE_NAME (was $LINE_COUNT lines)" >> "$LOG_FILE"
    fi
fi

# Clean up archives older than 90 days
find "$ARCHIVE_DIR" -name "backup_incidents-*.log" -mtime +90 -delete 2>/dev/null
