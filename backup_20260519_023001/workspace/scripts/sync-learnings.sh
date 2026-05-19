#!/bin/bash
# Sync Learnings — Auto-scan recent memory files and suggest learnings to capture
# Purpose: Review daily memory logs and extract improvements/issues for .learnings/
# Usage: bash sync-learnings.sh [--auto] [--days N]
# 
# --auto    = Auto-capture without prompts (recommended for cron)
# --days N  = Look back N days (default: 7)

set -euo pipefail

WORKSPACE_DIR="/home/node/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE_DIR/memory"
LEARNINGS_DIR="$WORKSPACE_DIR/.learnings"
AUTO_MODE=false
DAYS_BACK=7
TEMP_LOG="/tmp/learnings-scan-$$.txt"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --auto) AUTO_MODE=true; shift ;;
    --days) DAYS_BACK="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Ensure directories exist
mkdir -p "$LEARNINGS_DIR"

echo "🧠 Syncing Recent Learnings..."
echo "   Looking back $DAYS_BACK days"
echo ""

# Find recent memory files (modified in last N days)
RECENT_FILES=$(find "$MEMORY_DIR" -maxdepth 1 -name "2026-*.md" -type f -mtime -$DAYS_BACK 2>/dev/null | sort -r | head -20)

if [ -z "$RECENT_FILES" ]; then
  echo "ℹ️  No recent memory files found (older than $DAYS_BACK days)"
  exit 0
fi

echo "📄 Files to scan:"
echo "$RECENT_FILES" | while read f; do
  echo "   - $(basename "$f")"
done
echo ""

# Create temporary output for findings
{
  echo "=== Findings from $(date '+%Y-%m-%d %H:%M UTC') ==="
  echo ""
  
  # Scan for improvement-related keywords
  echo "## Potential Improvements Found:"
  grep -h "^- \*\*2026" "$RECENT_FILES" 2>/dev/null | head -20 || echo "   (none with explicit timestamps)"
  
  # Scan for tagged improvements in markdown
  echo ""
  echo "## Items tagged [improvement]:"
  grep -h "\[improvement\]" "$RECENT_FILES" 2>/dev/null | head -10 || echo "   (none found)"
  
  echo ""
  echo "## Items tagged [bug-fix] or [critical]:"
  grep -h "\[bug-fix\]\|\[critical\]" "$RECENT_FILES" 2>/dev/null | head -10 || echo "   (none found)"
  
} > "$TEMP_LOG"

# Display findings
cat "$TEMP_LOG"
echo ""

# Count current learnings
LEARNINGS_COUNT=$(grep -c "^- " "$LEARNINGS_DIR/LEARNINGS.md" 2>/dev/null || echo 0)
ERRORS_COUNT=$(grep -c "^- " "$LEARNINGS_DIR/ERRORS.md" 2>/dev/null || echo 0)

echo "📊 Current Status:"
echo "   - LEARNINGS.md: $LEARNINGS_COUNT entries"
echo "   - ERRORS.md: $ERRORS_COUNT entries"
echo ""

if [ "$AUTO_MODE" = false ]; then
  echo "💡 To capture learnings:"
  echo "   1. Review findings above"
  echo "   2. Edit: $LEARNINGS_DIR/LEARNINGS.md"
  echo "   3. Edit: $LEARNINGS_DIR/ERRORS.md"
  echo "   4. Or run: bash $0 --auto"
  echo ""
fi

# Auto-capture mode: append summary to learnings if substantial changes found
if [ "$AUTO_MODE" = true ]; then
  # Count improvement mentions in recent files
  improvement_count=$(grep -c "\[improvement\]\|\[bug-fix\]\|Fixed\|improved" "$RECENT_FILES" 2>/dev/null || echo 0)
  
  if [ "$improvement_count" -gt 0 ]; then
    {
      echo ""
      echo "## $(date '+%Y-%m-%d') — Auto-synced from memory"
      echo "- Scanned $DAYS_BACK days of memory files"
      echo "- Found $improvement_count improvement-related mentions"
      echo "- Details: See memory files for specifics"
    } >> "$LEARNINGS_DIR/LEARNINGS.md"
    
    echo "✅ Auto-synced: Updated LEARNINGS.md"
  else
    echo "ℹ️  No substantial learnings found to auto-capture"
  fi
fi

# Cleanup
rm -f "$TEMP_LOG"

echo "✅ Sync complete"
