#!/bin/bash

# Quick summary of backup validation history
# Shows recent incidents, patterns, and health status

LOG_FILE="/home/node/.openclaw/workspace/memory/backup_incidents.log"
ARCHIVE_DIR="/home/node/.openclaw/workspace/memory/backup_logs"

echo "📊 Backup Validation Summary"
echo "================================"
echo ""

if [ ! -f "$LOG_FILE" ]; then
    echo "❌ No active log found. Starting fresh."
    exit 0
fi

# Recent entries
RECENT=$(tail -20 "$LOG_FILE" 2>/dev/null | grep -E "WARNING|FAIL|OK:" | tail -5)
if [ -z "$RECENT" ]; then
    echo "✅ Last 5 checks: All passed"
else
    echo "📝 Last 5 significant entries:"
    echo "$RECENT"
fi

echo ""

# Count issues in active log
WARNINGS=$(grep -c "WARNING" "$LOG_FILE" 2>/dev/null || echo "0")
FAILS=$(grep -c "FAIL" "$LOG_FILE" 2>/dev/null || echo "0")
PASSES=$(grep -c "validation passed" "$LOG_FILE" 2>/dev/null || echo "0")

echo "📈 Active log stats:"
echo "   Passes: $PASSES"
echo "   Warnings: $WARNINGS"
echo "   Failures: $FAILS"

echo ""

# Archive summary
if [ -d "$ARCHIVE_DIR" ]; then
    ARCHIVE_COUNT=$(ls "$ARCHIVE_DIR" 2>/dev/null | wc -l)
    if [ "$ARCHIVE_COUNT" -gt 0 ]; then
        echo "📦 Archived logs: $ARCHIVE_COUNT files"
        OLDEST=$(ls -1 "$ARCHIVE_DIR" 2>/dev/null | head -1)
        NEWEST=$(ls -1 "$ARCHIVE_DIR" 2>/dev/null | tail -1)
        echo "   Oldest: $OLDEST"
        echo "   Newest: $NEWEST"
    fi
fi

echo ""
echo "💡 Tip: Run 'rotate_backup_log.sh' to archive old entries"
