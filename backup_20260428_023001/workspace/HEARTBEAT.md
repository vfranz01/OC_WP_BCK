# HEARTBEAT.md - Daily Checklist

## Verhalten

- Nachts (23:00–08:00 UTC): Sofort `HEARTBEAT_OK` — keine Tools, keine Checks.
- Tagsüber (08:00–23:00 UTC): Checks wie unten ausführen.
- Wenn nichts zu tun: `HEARTBEAT_OK` ohne weitere Ausgabe.

---

## 1. Backup Validation

```bash
if ! bash /home/node/.openclaw/workspace/scripts/validate_backup.sh; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Backup validation failed. Triggering snapshot." >> /home/node/.openclaw/workspace/memory/backup_incidents.log
  bash /home/node/.openclaw/workspace/scripts/trigger_backup_snapshot.sh
fi
touch /home/node/.openclaw/workspace/memory/backup_incidents.log
chmod +x /home/node/.openclaw/workspace/scripts/validate_backup.sh
```

---

## 2. Memory Maintenance (einmal täglich reicht)

- Neueste `memory/YYYY-MM-DD.md` auf wichtige Ereignisse prüfen.
- `MEMORY.md` mit destillierten Erkenntnissen aktualisieren.
- Veraltete Infos aus `MEMORY.md` entfernen.

---

## 3. Blog Job Check (NUR Mo=1 / Mi=3 / Fr=5)

Nur an Posting-Tagen prüfen ob der T-ShirtBull Cron-Job gelaufen ist:

```bash
DAY=$(date +%u)
if [[ "$DAY" == "1" || "$DAY" == "3" || "$DAY" == "5" ]]; then
  bash /home/node/.openclaw/workspace/scripts/check_tshirtbull_blogpost.sh
fi
```

Wenn kein Memory-Eintrag gefunden → kurz melden, kein Alarm.
