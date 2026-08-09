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
  
  # Skip files that already have frontmatter
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
    date=$(date -d "@$(stat -c %Y "$file")" +%Y-%m-%d 2>/dev/null || date -r "$file" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
    title_source=$(echo "$filename" | sed 's/\.md$//')
  fi
  
  # Extract title from filename and make snake/kebab case readable.
  title=$(echo "$title_source" | tr '_-' '  ' | sed 's/\b\(.\)/\u\1/g')
  [ -z "$title" ] && title="Log Entry"
  
  # Analyze content for tags (simple heuristics)
  tags=""
  content=$(cat "$file" | tr '[:upper:]' '[:lower:]')
  
  [[ "$content" =~ (heartbeat|check|status) ]] && tags="$tags,heartbeat"
  [[ "$content" =~ (blog|post|content) ]] && tags="$tags,blog"
  [[ "$content" =~ (tshirtbull|shopify) ]] && tags="$tags,tshirtbull"
  [[ "$content" =~ (ecomunivers|wordpress) ]] && tags="$tags,ecomunivers"
  [[ "$content" =~ (automation|cron|script) ]] && tags="$tags,automation"
  [[ "$content" =~ (error|fail|fix|issue) ]] && tags="$tags,incident"
  [[ "$content" =~ (backup|snapshot) ]] && tags="$tags,backup"
  [[ "$content" =~ (security|key|credential) ]] && tags="$tags,security"
  
  # Clean up tags (remove leading comma, convert to array)
  tags=$(echo "$tags" | sed 's/^,//; s/,/", "/g')
  [ ! -z "$tags" ] && tags="$tags"
  
  # Extract first substantive line as summary (max 80 chars)
  summary=$(grep -v "^$" "$file" | head -3 | tail -1 | cut -c1-80)
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
