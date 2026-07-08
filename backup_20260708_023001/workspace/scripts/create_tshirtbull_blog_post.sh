#!/bin/bash

# Create T-ShirtBull blog post workflow marker
# Usage: ./create_tshirtbull_blog_post.sh [day_of_week]
#
# Current scope: validates the scheduled day and records an auditable workflow
# entry. It intentionally does NOT claim a Shopify publish until publishing logic
# is implemented.

set -u

WORKSPACE_DIR="/home/node/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE_DIR/memory"
LOG_FILE="$MEMORY_DIR/create_tshirtbull_blog_post.log"
MEMORY_FILE="$MEMORY_DIR/$(date +%Y-%m-%d).md"
DAY_OF_WEEK=${1:-}

mkdir -p "$MEMORY_DIR"
bash "$WORKSPACE_DIR/scripts/create_daily_memory_file.sh" >/dev/null 2>&1 || true

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Validate day of week
if [ -z "$DAY_OF_WEEK" ]; then
  log "Fehler: Wochentag nicht angegeben"
  exit 1
fi

# Determine blog post type and category based on day of week
case "$DAY_OF_WEEK" in
  "Mo"|"Montag")
    POST_TYPE="Produkt Showcase"
    BLOG_ID="88815468763"
    ;;
  "Mi"|"Mittwoch")
    POST_TYPE="Sprüche / Humor"
    BLOG_ID="89398968539"
    ;;
  "Fr"|"Freitag")
    POST_TYPE="Geschenkidee / Seasonal"
    BLOG_ID="88815468763"
    ;;
  *)
    log "Fehler: Ungültiger Wochentag: $DAY_OF_WEEK"
    exit 1
    ;;
esac

# TODO:
# 1. Choose a keyword from SEO list (considering season)
# 2. Write an article in German (800-1200 words)
# 3. Publish directly via Shopify API

log "Geplant: $POST_TYPE Blog-Post für T-ShirtBull (blog_id=$BLOG_ID)"

cat >> "$MEMORY_FILE" <<EOF

## T-ShirtBull Blog Workflow — $(date '+%H:%M UTC')
- Geplanter Blog-Typ: $POST_TYPE
- Shopify Blog ID: $BLOG_ID
- Status: vorbereitet/protokolliert; Publishing-Logik noch nicht implementiert.
EOF

echo "✅ T-ShirtBull workflow logged: $POST_TYPE (blog_id=$BLOG_ID)"
