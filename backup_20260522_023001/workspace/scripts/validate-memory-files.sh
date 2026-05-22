#!/bin/bash
# Validate memory files format and consistency
# Ensures all .md files in memory/ follow documented frontmatter structure
# Part of the self-improving maintenance cycle

WORKSPACE_DIR="/home/node/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE_DIR/memory"
REPORT_FILE="$MEMORY_DIR/.validation_report.md"
EXIT_CODE=0

echo "🔍 Memory File Validator"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if memory directory exists
if [ ! -d "$MEMORY_DIR" ]; then
  echo "⚠️  Memory directory not found: $MEMORY_DIR"
  mkdir -p "$MEMORY_DIR"
  echo "✅ Created memory directory"
fi

# Count files
TOTAL_FILES=$(find "$MEMORY_DIR" -name "*.md" -type f | wc -l)
VALID_FILES=0
MISSING_FRONTMATTER=0
MISSING_BODY=0
STALE_FILES=0
FILES_WITH_ISSUES=()

echo "📋 Scanning $TOTAL_FILES memory files..."
echo ""

# Validation thresholds
STALE_DAYS=7
TODAY_UNIX=$(date +%s)

for file in "$MEMORY_DIR"/*.md; do
  filename=$(basename "$file")
  
  # Skip hidden/special files
  if [[ "$filename" =~ ^\..*$ ]]; then
    continue
  fi
  
  # Check for YAML frontmatter (---...---)
  if head -1 "$file" | grep -q "^---$"; then
    # Check if file has closing ---
    if grep -q "^---$" <(head -20 "$file"); then
      VALID_FILES=$((VALID_FILES + 1))
      
      # Check if file has content beyond frontmatter
      body_line_count=$(tail -n +5 "$file" | wc -l)
      if [ "$body_line_count" -lt 2 ]; then
        echo "⚠️  $filename - Has frontmatter but minimal body"
        MISSING_BODY=$((MISSING_BODY + 1))
        FILES_WITH_ISSUES+=("$filename")
        EXIT_CODE=1
      else
        echo "✅ $filename"
      fi
    else
      echo "❌ $filename - Incomplete frontmatter (missing closing ---)"
      MISSING_FRONTMATTER=$((MISSING_FRONTMATTER + 1))
      FILES_WITH_ISSUES+=("$filename")
      EXIT_CODE=1
    fi
  else
    echo "❌ $filename - Missing YAML frontmatter"
    MISSING_FRONTMATTER=$((MISSING_FRONTMATTER + 1))
    FILES_WITH_ISSUES+=("$filename")
    EXIT_CODE=1
  fi
  
  # Check for stale files (no modifications in N days)
  file_mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
  if [ ! -z "$file_mtime" ]; then
    age_days=$(( (TODAY_UNIX - file_mtime) / 86400 ))
    if [ "$age_days" -gt "$STALE_DAYS" ]; then
      echo "⏱️  $filename - Last modified ${age_days} days ago"
      STALE_FILES=$((STALE_FILES + 1))
    fi
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total files: $TOTAL_FILES"
echo "✅ Valid format: $VALID_FILES"
echo "❌ Missing frontmatter: $MISSING_FRONTMATTER"
echo "⚠️  Missing/minimal body: $MISSING_BODY"
echo "⏱️  Stale (>$STALE_DAYS days): $STALE_FILES"

if [ "$EXIT_CODE" -eq 0 ]; then
  echo ""
  echo "✅ All memory files valid"
else
  echo ""
  echo "⚠️  Issues found in memory files"
  echo "Fix: Add YAML frontmatter with date, title, tags, summary"
fi

exit $EXIT_CODE
