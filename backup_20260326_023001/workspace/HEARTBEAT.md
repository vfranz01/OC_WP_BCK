# HEARTBEAT.md - Daily Checklist

## Daily Tasks

### 1. Backup Validation
Ensure backup scripts are executable and validate critical files:
```bash
chmod +x /home/node/.openclaw/workspace/scripts/validate_backup.sh /home/node/.openclaw/workspace/scripts/trigger_backup_snapshot.sh 2>/dev/null || true
bash /home/node/.openclaw/workspace/scripts/validate_backup.sh
```

### 2. Memory Maintenance
- Review recent `memory/YYYY-MM-DD.md` files for significant events.
- Update `MEMORY.md` with distilled learnings.
- Remove outdated info from `MEMORY.md`.

### 3. Proactive Checks
- **Emails:** Check for urgent unread messages.
- **Calendar:** Check for upcoming events in the next 24-48 hours.
- **Weather:** Check if relevant to Volker's plans.

### 4. Stay Quiet When Appropriate
- Late night (23:00-08:00) unless urgent.
- If Volker is busy or nothing new since the last check, reply `HEARTBEAT_OK`.