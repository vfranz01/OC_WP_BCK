#!/bin/bash
# Fix memory files by adding missing YAML frontmatter
# Extracts date from filename and analyzes content for tags/summary
# Safe: creates backups before modifying

WORKSPACE_DIR="/home/node/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE_DIR/memory"
BACKUP_DIR="$MEMORY_DIR/.backups"
FIXED=0
SKIPPED=0

mkdir -p "$BACKUP_DIR"

echo "🔧 Memory File Frontmatter Fixer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Adding YAML frontmatter to files missing it..."
echo ""

for file in "$MEMORY_DIR"/*.md; do
  filename=$(basename "$file")
  
  # Skip hidden/special files
  if [[ "$filename" =~ ^\..*$ ]]; then
    continue
  fi
  
  # Repair the specific malformed tags form previously emitted by this script
  # (for example: tags: [automation", "incident]).  The validator correctly
  # rejects it, but the old fixer only handled missing frontmatter, so health
  # checks could remain red forever.  Only touch an odd-quote flow-list inside
  # frontmatter; valid YAML is left byte-for-byte unchanged.
  if head -1 "$file" | grep -q "^---$"; then
    if ! repair_output=$(python3 - "$file" "$BACKUP_DIR/${filename}.bak" <<'PY'
from pathlib import Path
import re
import shutil
import sys

path = Path(sys.argv[1])
backup = Path(sys.argv[2])
lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
if not lines or lines[0].rstrip("\n") != "---":
    raise SystemExit(0)

end = next((i for i, line in enumerate(lines[1:], 1) if line.rstrip("\n") == "---"), None)
if end is None:
    raise SystemExit(0)

changed = False
for i in range(1, end):
    match = re.match(r'^(tags:\s*)\[(.*)\](\s*)\n?$', lines[i])
    if not match:
        continue
    inner = match.group(2)
    # Detect both historical malformed forms: an unclosed quoted token and a
    # quote appearing in the middle of a plain token (e.g. automation").
    in_quote = False
    expect_token = True
    malformed = False
    for char in inner:
        if in_quote:
            if char == '"':
                in_quote = False
            continue
        if char == '"':
            if not expect_token:
                malformed = True
            in_quote = True
        elif char == ',':
            expect_token = True
        elif not char.isspace():
            expect_token = False
    if in_quote:
        malformed = True
    if not malformed:
        continue
    values = [part.strip().strip('"').strip("'") for part in inner.split(',')]
    values = [value for value in values if value]
    if not values:
        continue
    newline = "\n" if lines[i].endswith("\n") else ""
    lines[i] = f'{match.group(1)}[' + ", ".join(f'"{value}"' for value in values) + f']{match.group(3)}{newline}'
    changed = True

if changed:
    if not backup.exists():
        shutil.copy2(path, backup)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text("".join(lines), encoding="utf-8")
    tmp.replace(path)
    print(path.name)
PY
    ); then
      echo "⚠️ Failed to inspect frontmatter in $filename" >&2
      exit 1
    fi
    if [ -n "$repair_output" ]; then
      echo "✅ Repaired malformed tags in $repair_output"
      FIXED=$((FIXED + 1))
    fi
    # Files with frontmatter do not need the missing-frontmatter path below.
    continue
  fi

  # Skip files that already have valid frontmatter
  if head -1 "$file" | grep -q "^---$"; then
    continue
  fi
  
  # Extract date from filename (YYYY-MM-DD format). For undated helper notes,
  # fall back to the file modification date so the fixer can repair all memory/*.md
  # files instead of leaving one permanent validator failure behind.
  if [[ "$filename" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
    date="${BASH_REMATCH[1]}"
    title_source=$(echo "$filename" | sed "s/^${date}-//; s/\.md$//")
  else
    date=$(date -d "@$(stat -c %Y "$file")" +%Y-%m-%d 2>/dev/null || date -r "$file" +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)
    title_source=$(echo "$filename" | sed 's/\.md$//')
  fi
  
  # Extract title from filename and make snake/kebab case readable.
  title=$(echo "$title_source" | tr '_-' '  ' | sed 's/\b\(.\)/\u\1/g')
  [ -z "$title" ] && title="Log Entry"
  
  # Analyze content for tags (simple heuristics)
  tags=""
  content=$(cat "$file" | tr '[:upper:]' '[:lower:]')
  
  # Word-boundary heuristics: substring matches caused false positives
  # (e.g. "key" inside "Keyword" → bogus security tag).
  [[ "$content" =~ (heartbeat|check|status) ]] && tags="$tags,heartbeat"
  [[ "$content" =~ (blog|post|content) ]] && tags="$tags,blog"
  [[ "$content" =~ (tshirtbull|shopify) ]] && tags="$tags,tshirtbull"
  [[ "$content" =~ (ecomunivers|wordpress) ]] && tags="$tags,ecomunivers"
  [[ "$content" =~ (automation|cron|script) ]] && tags="$tags,automation"
  [[ "$content" =~ (error|fail|fix|issue) ]] && tags="$tags,incident"
  [[ "$content" =~ (backup|snapshot) ]] && tags="$tags,backup"
  [[ "$content" =~ (^|[^a-z])key([^a-z]|$) ]] && tags="$tags,security"
  
  # Clean up tags (remove leading comma, convert to array)
  tags=$(echo "$tags" | sed 's/^,//; s/,/", "/g')
  [ ! -z "$tags" ] && tags="\"$tags\""
  
  # Prefer a real heading as summary; skip bullets, tables and metadata lines
  # that produced garbage summaries like "- **Article-ID:** 12345".
  summary=$(grep -v '^$' "$file" | grep -v '^- ' | grep -v '^[*|>]' | head -1 | sed 's/^#\+ *//; s/\*\*//g' | cut -c1-80)
  [ -z "$summary" ] && summary=$(grep -v '^$' "$file" | head -1 | sed 's/^#\+ *//; s/\*\*//g' | cut -c1-80)
  [ -z "$summary" ] && summary="Work log entry"
  
  # Create frontmatter
  frontmatter="---
date: $date
title: $title
tags: [${tags:-general}]
projects: [general]
summary: $summary
---

"
  
  # Backup original
  cp "$file" "$BACKUP_DIR/${filename}.bak"
  
  # Write new content with frontmatter
  {
    echo "$frontmatter"
    cat "$file"
  } > "${file}.tmp"
  
  mv "${file}.tmp" "$file"
  
  echo "✅ Fixed $filename"
  FIXED=$((FIXED + 1))
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Fixed: $FIXED files"
echo "⏭️  Skipped: $SKIPPED files (couldn't determine date)"
echo "💾 Backups: $BACKUP_DIR/"
echo ""
echo "✅ All memory files now have proper frontmatter"
