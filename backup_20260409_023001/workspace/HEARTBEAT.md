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

### 7. Check for Blog Post
```bash
ls /home/node/.openclaw/workspace/memory/$(date +%Y-%m-%d)*.md 2>/dev/null && \
grep -l "blog\|post\|draft" /home/node/.openclaw/workspace/memory/$(date +%Y-%m-%d)*.md 2>/dev/null || \
grep -l "blog\|post\|draft" /home/node/.openclaw/workspace/memory/$(date -d "-1 day" +%Y-%m-%d)*.md 2>/dev/null || \
grep -l "blog\|post\|draft" /home/node/.openclaw/workspace/memory/$(date -d "-2 day" +%Y-%m-%d)*.md 2>/dev/null || \
grep -l "blog\|post\|draft" /home/node/.openclaw/workspace/memory/$(date -d "-3 day" +%Y-%m-%d)*.md 2>/dev/null || \
grep -l "blog\|post\|draft" /home/node/.openclaw/workspace/memory/$(date -d "-4 day" +%Y-%m-%d)*.md 2>/dev/null || \
grep -l "blog\|post\|draft" /home/node/.openclaw/workspace/memory/$(date -d "-5 day" +%Y-%m-%d)*.md 2>/dev/null || \
grep -l "blog\|post\|draft" /home/node/.openclaw/workspace/memory/$(date -d "-6 day" +%Y-%m-%d)*.md 2>/dev/null || \
echo "⚠️ Kein Memory-Eintrag für Blog-Job in den letzten 7 Tagen gefunden"
```

### 8. Stay Quiet When Appropriate
- Late night (23:00-08:00) unless urgent.
- If Volker is busy or nothing new since the last check, reply `HEARTBEAT_OK`.
### 5. Blog Job Validation (Mo / Mi / Fr)
An Montagen, Mittwoch und Freitagen prüfen ob der Blog-Job gelaufen ist:
```bash
ls /home/node/.openclaw/workspace/memory/$(date +%Y-%m-%d)*.md 2>/dev/null && \
grep -l "blog\|post\|draft" /home/node/.openclaw/workspace/memory/$(date +%Y-%m-%d)*.md 2>/dev/null || \
grep -l "blog\|post\|draft" /home/node/.openclaw/workspace/memory/$(date -d "-1 day" +%Y-%m-%d)*.md 2>/dev/null || \
grep -l "blog\|post\|draft" /home/node/.openclaw/workspace/memory/$(date -d "-2 day" +%Y-%m-%d)*.md 2>/dev/null || \
grep -l "blog\|post\|draft" /home/node/.openclaw/workspace/memory/$(date -d "-3 day" +%Y-%m-%d)*.md 2>/dev/null || \
grep -l "blog\|post\|draft" /home/node/.openclaw/workspace/memory/$(date -d "-4 day" +%Y-%m-%d)*.md 2>/dev/null || \
grep -l "blog\|post\|draft" /home/node/.openclaw/workspace/memory/$(date -d "-5 day" +%Y-%m-%d)*.md 2>/dev/null || \
grep -l "blog\|post\|draft" /home/node/.openclaw/workspace/memory/$(date -d "-6 day" +%Y-%m-%d)*.md 2>/dev/null || \
echo "⚠️ Kein Memory-Eintrag für Blog-Job in den letzten 7 Tagen gefunden"
```
- Wenn kein Eintrag → Volker informieren, manuell via Telegram triggern
- Erwartete Posting-Zeiten: 9:00 AM AEST
- Mo: Evergreen SEO Post (Category 57)
- Mi: How-To / Guide (Category 57)
- Fr: News / Trending (Category 17)

### 6. T-ShirtBull Blog Job (Mo / Mi / Fr)
An Montagen, Mittwoch und Freitagen einen Blog-Post für t-shirtbull.com erstellen:
- Skill lesen: /home/node/.openclaw/workspace/skills/tshirtbull/SKILL.md
- Keyword aus SEO-Liste wählen (Saison beachten!)
- Artikel auf Deutsch schreiben (800-1200 Wörter)
- Direkt via Shopify API publishen (published: true)
- API Endpoint: https://85e8f2.myshopify.com/admin/api/2026-04/blogs/BLOG_ID/articles.json
- Token: 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
- Mo: Produkt Showcase → Blog news (ID: 88815468763)
- Mi: Sprüche / Humor → Blog bierspruche (ID: 89398968539)
- Fr: Geschenkidee / Seasonal → Blog news (ID: 88815468763)
- Nach dem Post: Memory-Eintrag erstellen mit Titel und URL
