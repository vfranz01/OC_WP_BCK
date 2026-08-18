#!/bin/bash
# Distill potential learnings from daily memory logs.
# This script identifies error messages, workarounds, and significant events from recent .md files
# in the memory directory and formats them as potential entries for MEMORY.md.
# It outputs the results to stdout in a format suitable for review and manual promotion.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MEMORY_DIR="$WORKSPACE_DIR/memory"
DAYS_TO_REVIEW=3 # Look back 3 days for potential learnings

echo "🔍 Distilling potential learnings from the last $DAYS_TO_REVIEW days..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Temporary file to store distilled learnings
DISTILLATION_OUTPUT=$(mktemp /tmp/distill-learnings.XXXXXX.md)
trap 'rm -f "$DISTILLATION_OUTPUT"' EXIT

echo "---" > "$DISTILLATION_OUTPUT"
echo "date: $(date -u +%Y-%m-%d)" >> "$DISTILLATION_OUTPUT"
echo "title: Potential Learnings Distilled" >> "$DISTILLATION_OUTPUT"
echo "tags: [learning, distillation, automation]" >> "$DISTILLATION_OUTPUT"
echo "projects: []" >> "$DISTILLATION_OUTPUT"
echo "summary: Distilled potential learnings from recent daily logs." >> "$DISTILLATION_OUTPUT"
echo "---" >> "$DISTILLATION_OUTPUT"
echo "" >> "$DISTILLATION_OUTPUT"
echo "## Potential Learnings (Review and Promote to MEMORY.md)" >> "$DISTILLATION_OUTPUT"
echo "" >> "$DISTILLATION_OUTPUT"

found_learnings=false

# Loop through the last DAYS_TO_REVIEW days
for i in $(seq 0 $((DAYS_TO_REVIEW - 1))); do
  DATE=$(date -u -d "$i days ago" "+%Y-%m-%d")
  LOG_FILE="$MEMORY_DIR/${DATE}.md"

  if [ -f "$LOG_FILE" ]; then
    echo "🔎 Processing: $LOG_FILE"

    # --- Logic to extract potential learnings ---
    # 1. Look for error messages (keywords like ERROR, WARN, FAIL, ⚠️, ❌)
    # 2. Look for successful workarounds or specific actions taken (e.g., lines starting with specific commands, or logical outcomes)
    # 3. Look for mentions of specific projects that had issues or successes.

    # Example: Extract lines containing ERROR or FAIL, or specific keywords
    # This is a basic starting point and can be refined.
    grep -E 'ERROR|FAIL|WARN|ERROR:|FATAL|exception|Traceback' "$LOG_FILE" | while IFS= read -r line; do
      echo "  - **Potential Error/Issue:** $line" >> "$DISTILLATION_OUTPUT"
      found_learnings=true
    done

    # Example: Extract lines related to specific scripts or known common issues (like blog posts)
    grep -E 'scripts/check_blog_posts.py|validate_backup.sh|openclaw gateway status unclear|curl allowedDomains may be missing' "$LOG_FILE" | while IFS= read -r line; do
      echo "  - **Specific Observation:** $line" >> "$DISTILLATION_OUTPUT"
      found_learnings=true
    done
    
    # Example: Extract lines that indicate a positive outcome after a problem
    grep -E '✅ Backup valid|✅ curl allowedDomains configured|✅ All critical files present|✅ OpenClaw Gateway healthy' "$LOG_FILE" | while IFS= read -r line; do
      # Avoid adding too much noise if healthy status is routine
      if [[ "$line" != *"System healthy"* ]]; then 
        echo "  - **Success Indicator:** $line" >> "$DISTILLATION_OUTPUT"
        found_learnings=true
      fi
    done

  else
    echo "  - Skipping: $LOG_FILE (not found)"
  fi
done

if [ "$found_learnings" = false ]; then
  echo ""
  echo "✨ No significant potential learnings found in the last $DAYS_TO_REVIEW days."
  # Clean up the file if it only contains the header and no learnings
  if [ $(wc -l < "$DISTILLATION_OUTPUT") -le 15 ]; then
    rm "$DISTILLATION_OUTPUT"
  fi
else
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ Distillation complete. Potential learnings saved to:"
  echo "$DISTILLATION_OUTPUT"
  echo "Please review and manually add relevant items to MEMORY.md."
fi

exit 0
