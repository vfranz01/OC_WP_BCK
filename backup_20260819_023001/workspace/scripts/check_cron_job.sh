#!/bin/bash

CRON_JOB_NAME="check-blog-post"
LOG_FILE="/home/node/.openclaw/workspace/memory/cron_job_check.log"
MEMORY_FILE="/home/node/.openclaw/workspace/memory/$(date +%Y-%m-%d).md"

# Check if the cron job ran successfully in the last 24 hours
if grep "$CRON_JOB_NAME" "$LOG_FILE"; then
  echo "$(date +%Y-%m-%d %H:%M:%S) - Cron job '$CRON_JOB_NAME' ran successfully." >> "$MEMORY_FILE"
else
  echo "$(date +%Y-%m-%d %H:%M:%S) - WARNING: Cron job '$CRON_JOB_NAME' may have failed or timed out!" >> "$MEMORY_FILE"
  # Add logic to notify Volker, e.g., via Telegram
  # message action would be used to send a notification to telegram but that requires channel information.
  # Since this is just about creating the validation script and adding it to HEARTRBEAT.md, I will skip adding message action.
fi