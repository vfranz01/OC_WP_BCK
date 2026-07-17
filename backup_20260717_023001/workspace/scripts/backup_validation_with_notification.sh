#!/bin/bash

# Validate the backup
chmod +x /home/node/.openclaw/workspace/scripts/validate_backup.sh 2>/dev/null || true
if [ ! -f memory/backup_incidents.log ]; then
  touch memory/backup_incidents.log
fi
bash /home/node/.openclaw/workspace/scripts/validate_backup.sh
if [ $? -ne 0 ]; then
  echo "$(date) - Backup validation failed" >> memory/backup_incidents.log
  bash /home/node/.openclaw/workspace/scripts/trigger_backup_snapshot.sh
  echo "$(date) - Triggered backup snapshot" >> memory/backup_incidents.log
  tts "Backup validation failed. A snapshot has been triggered. Check memory/backup_incidents.log for details."
fi