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
BAD_TAGS=0
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

      # Frontmatter syntax check: tags: flow-list lines must be well-formed YAML.
      # Mini-lexer: a `"` only opens a quoted scalar at token start (after `[`
      # or `,`); a `"` mid-plain-scalar is legal YAML and ignored. A token that
      # starts a quoted scalar must close its quote before end-of-line, and the
      # line must end on `]`. Catches stray quotes like `tags: [a", "b]` (an
      # unclosed quoted scalar) that the structural checks above cannot see.
      # Valid styles accepted: [a, b] and ["a", "b"].
      fm_block="$(awk 'NR==1{next} /^---$/{exit} {print}' "$file")"
      bad_tags="$(printf '%s\n' "$fm_block" | grep -E '^tags:' | awk '
        {
          line=$0
          if (index(line, "[") == 0) next   # not a flow list; nothing to check
          n=length(line)
          if (substr(line,n,1) != "]") { print line; next }
          inq=0; expect=1   # expect=1: next non-space char starts a token
          for (i=1; i<=n; i++) {
            c=substr(line,i,1)
            if (inq) { if (c == "\"") inq=0; continue }
            if (c == "\"") { if (expect) inq=1; expect=0; continue }
            if (c == "[" || c == ",") { expect=1; continue }
            if (c == " " || c == "]") continue
            expect=0   # plain-scalar character
          }
          if (inq != 0) print line   # unclosed quoted scalar
        }')"
      if [ -n "$bad_tags" ]; then
        echo "❌ $filename - Malformed tags: flow-list in frontmatter: $(echo "$bad_tags" | head -1)"
        BAD_TAGS=$((BAD_TAGS + 1))
        FILES_WITH_ISSUES+=("$filename")
        EXIT_CODE=1
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
echo "❌ Malformed tags flow-list: $BAD_TAGS"
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
