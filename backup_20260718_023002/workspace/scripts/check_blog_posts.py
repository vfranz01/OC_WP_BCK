#!/bin/bash
# Check Blog Posts Script
# Checks for upcoming blog posts based on a simple naming convention in the blog directory.
# Assumes blog posts are named YYYY-MM-DD-title.md

# Default values
DEFAULT_BLOG_DIR="/home/node/.openclaw/workspace/blog_posts" # ASSUMPTION: Blog posts are in a 'blog_posts' subdirectory
DEFAULT_DAYS_AHEAD=7

# --- Argument Parsing ---
BLOG_DIR="${1:-$DEFAULT_BLOG_DIR}" # Use first argument, or default if not provided
DAYS_AHEAD="${2:-$DEFAULT_DAYS_AHEAD}" # Use second argument, or default if not provided

# --- Configuration ---
WORKSPACE_DIR="/home/node/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE_DIR/memory"
# Changed log file to be more specific
BLOG_CHECK_LOG="$MEMORY_DIR/blog_check_status.log"

# Current date and future date
TODAY=$(date +%Y-%m-%d)
FUTURE_DATE=$(date -d "+$DAYS_AHEAD days" +%Y-%m-%d)

echo "--------------------------------------------------"
echo "Running blog post check:"
echo "Blog Directory: $BLOG_DIR"
echo "Days Ahead: $DAYS_AHEAD"
echo "Checking from $TODAY to $FUTURE_DATE"
echo "--------------------------------------------------"

# Check if the blog directory exists and is readable
if [ ! -d "$BLOG_DIR" ]; then
  echo "ERROR: Blog directory '$BLOG_DIR' not found or not accessible. Skipping check."
  # Ensure memory directory exists before writing log
  mkdir -p "$MEMORY_DIR"
  echo "$(date +%Y-%m-%d) - ERROR: Blog directory '$BLOG_DIR' not found or not accessible." >> "$BLOG_CHECK_LOG"
  exit 1 # Exit with error code
fi

# Ensure memory directory exists, in case it was missing
mkdir -p "$MEMORY_DIR"

# Find blog posts within the next DAYS_AHEAD days
UPCOMING_POSTS=$(find "$BLOG_DIR" -maxdepth 1 -name '????-??-??-*.md' -type f | while read -r file; do
  # Extract date from filename using sed for robustness
  filename=$(basename "$file")
  post_date=$(echo "$filename" | sed -n 's/^\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)-.*$/\1/p')

  # Check if the extracted date is valid and within the range
  if [[ -n "$post_date" ]] && [[ "$post_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ "$post_date" > "$TODAY" ]] && [[ "$post_date" < "$FUTURE_DATE" ]]; then
    echo "$file (Date: $post_date)"
  fi
done)

# Determine exit status and log message
if [ -z "$UPCOMING_POSTS" ]; then
  echo "✅ No upcoming blog posts found in the next $DAYS_AHEAD days."
  echo "$(date +%Y-%m-%d) - INFO: No upcoming blog posts found in the next $DAYS_AHEAD days." >> "$BLOG_CHECK_LOG"
  exit 0 # Exit with success code
else
  echo "⚠️ Upcoming blog posts found in the next $DAYS_AHEAD days:"
  echo "$UPCOMING_POSTS"
  echo "$(date +%Y-%m-%d) - WARN: Upcoming blog posts found in the next $DAYS_AHEAD days:" >> "$BLOG_CHECK_LOG"
  echo "$UPCOMING_POSTS" >> "$BLOG_CHECK_LOG"
  exit 1 # Exit with error code to indicate action might be needed
fi