#!/bin/bash
# Check Blog Posts Script
# Checks for upcoming blog posts based on a simple naming convention in the blog directory.
# Assumes blog posts are named YYYY-MM-DD-title.md

# IMPORTANT: This script is a placeholder and relies on a specific,
# *unspecified* directory structure for blog posts.
# For practical use, it needs to be adapted to the actual blog setup.

WORKSPACE_DIR="/home/node/.openclaw/workspace"
BLOG_DIR="$WORKSPACE_DIR/blog_posts" # ASSUMPTION: Blog posts are in a 'blog_posts' subdirectory
MEMORY_DIR="$WORKSPACE_DIR/memory"
INCIDENT_LOG="$MEMORY_DIR/backup_incidents.log"

# Number of days ahead to check for upcoming posts
DAYS_AHEAD=7

# Current date and future date
TODAY=$(date +%Y-%m-%d)
FUTURE_DATE=$(date -d "+$DAYS_AHEAD days" +%Y-%m-%d)

echo "Checking for upcoming blog posts..."

# Check if the blog directory exists
if [ ! -d "$BLOG_DIR" ]; then
  echo "blog directory '$BLOG_DIR' not found. Skipping blog post check."
  exit 0
fi

# Find blog posts within the next DAYS_AHEAD days
UPCOMING_POSTS=$(find "$BLOG_DIR" -maxdepth 1 -name '????-??-??-*.md' -type f | while read -r file; do
  # Extract date from filename
  filename=$(basename "$file")
  post_date=$(echo "$filename" | grep -Eo '^[0-9]{4}-[0-9]{2}-[0-9]{2}')

  # Check if the extracted date is valid and within the range
  if [[ "$post_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ "$post_date" > "$TODAY" ]] && [[ "$post_date" < "$FUTURE_DATE" ]]; then
    echo "$file (Date: $post_date)"
  fi
done)

if [ -z "$UPCOMING_POSTS" ]; then
  echo "✅ No blog posts due in the next $DAYS_AHEAD days."
else
  echo "⚠️ Upcoming blog posts in the next $DAYS_AHEAD days:"
  echo "$UPCOMING_POSTS"
  # Log to incident log if there are upcoming posts, as this might require attention
  echo "$TODAY - ⚠️ Upcoming blog posts found: $UPCOMING_POSTS" >> "$INCIDENT_LOG"
fi

exit 0
