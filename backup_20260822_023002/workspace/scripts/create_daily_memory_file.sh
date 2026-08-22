#!/bin/bash
# Create the daily memory file if it doesn't exist.
# Safe to run from any working directory; resolves paths relative to this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MEMORY_DIR="$WORKSPACE_DIR/memory"
TEMPLATE_FILE="$MEMORY_DIR/template.md"
TODAY="${1:-$(date +%Y-%m-%d)}"
MEMORY_FILE="$MEMORY_DIR/${TODAY}.md"
LOG_FILE="/tmp/create_daily_memory_file.log"

if ! [[ "$TODAY" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "ERROR: Invalid date '$TODAY' (expected YYYY-MM-DD)" | tee -a "$LOG_FILE" >&2
  exit 1
fi

mkdir -p "$MEMORY_DIR"

if [ -f "$MEMORY_FILE" ]; then
  echo "Daily memory file already exists: $MEMORY_FILE"
  exit 0
fi

echo "Creating daily memory file: $MEMORY_FILE"
TMP_FILE="$(mktemp "$MEMORY_DIR/.${TODAY}.tmp.XXXXXX")"
trap 'rm -f "$TMP_FILE"' EXIT

if [ -f "$TEMPLATE_FILE" ]; then
  sed "s/YYYY-MM-DD/$TODAY/g" "$TEMPLATE_FILE" > "$TMP_FILE"
else
  cat > "$TMP_FILE" <<EOF
---
date: $TODAY
title: Daily Log
tags: [daily]
projects: []
summary: Daily activity log
---

## Was heute passiert ist

## Actions Taken

## Notes

EOF
fi

# Guardrail: daily logs must not be frontmatter-only.
if ! grep -q '^## ' "$TMP_FILE"; then
  cat >> "$TMP_FILE" <<'EOF'

## Was heute passiert ist

## Actions Taken

## Notes

EOF
fi

mv "$TMP_FILE" "$MEMORY_FILE"
trap - EXIT

echo "Created daily memory file: $MEMORY_FILE"
