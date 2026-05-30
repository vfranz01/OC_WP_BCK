#!/bin/bash
# Create daily memory file if it doesn't exist

TODAY=$(date +%Y-%m-%d)
MEMORY_FILE="memory/${TODAY}.md"

if [ ! -f "$MEMORY_FILE" ]; then
  echo "Creating daily memory file: ${MEMORY_FILE}"
  touch "$MEMORY_FILE"
  echo "---" >> "$MEMORY_FILE"
  echo "date: ${TODAY}" >> "$MEMORY_FILE"
  echo "title: Daily Log" >> "$MEMORY_FILE"
  echo "tags: [daily]" >> "$MEMORY_FILE"
  echo "projects: []" >> "$MEMORY_FILE"
  echo "summary: Daily activity log" >> "$MEMORY_FILE"
  echo "---" >> "$MEMORY_FILE"
  echo "" >> "$MEMORY_FILE"
  echo "## Was heute passiert ist" >> "$MEMORY_FILE"
  echo "" >> "$MEMORY_FILE"
  echo "## Actions Taken" >> "$MEMORY_FILE"
  echo "" >> "$MEMORY_FILE"
  echo "## Notes" >> "$MEMORY_FILE"
  echo "" >> "$MEMORY_FILE"
else
  echo "Daily memory file already exists: ${MEMORY_FILE}"
fi
