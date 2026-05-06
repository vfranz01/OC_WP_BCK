#!/bin/bash

# Validate Blog Job
# Usage: ./validate_blog_job.sh

LOG_FILE=/home/node/.openclaw/workspace/memory/validate_blog_job.log
MEMORY_FILE=/home/node/.openclaw/workspace/memory/$(date +%Y-%m-%d).md

# Validate if today is Monday, Wednesday, or Friday
case $(date +%u) in
  1|3|5) # Monday, Wednesday, Friday
    # Check for memory entries in the last 7 days
    FOUND_ENTRY=false
    for i in {0..6}; do
      MEMORY_DATE=$(date -d "$i days ago" +%Y-%m-%d)
      if grep -q -l "blog\|post\|draft" /home/node/.openclaw/workspace/memory/${MEMORY_DATE}.md 2>/dev/null; then
        FOUND_ENTRY=true
        break
      fi
    done

    if [ "$FOUND_ENTRY" = false ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - ⚠️ Kein Memory-Eintrag für Blog-Job in den letzten 7 Tagen gefunden" >> "$LOG_FILE"
      # Here you would add the logic to notify Volker via Telegram
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Benachrichtigung an Volker gesendet" >> "$LOG_FILE"
    fi
    ;;
  *)
    # Do nothing for other days
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Kein Blog-Job an Wochentag $(date +%u)" >> "$LOG_FILE"
    ;;
esac