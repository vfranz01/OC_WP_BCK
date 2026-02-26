# MEMORY.md — Long-Term Memory

## 🚨 CRITICAL RULE: No Changes Without Backup
**BEFORE any config change, gateway patch, or destructive action: run a snapshot first.**
```bash
bash /home/node/.openclaw/workspace/scripts/snapshot.sh "reason"
```
Volker has lost 2 previous installations (3+ days each). This rule is non-negotiable.

## Timeline
- **Do not restart OpenClaw unless instructed by Volker.**
- **Do not send scheduled reminders about the Brain's status; only check its status.**

## 🐳 Infrastructure & Paths

### OpenClaw Container (openclaw-gateway-1)
- **Image:** `ghcr.io/openclaw/openclaw:2026.2.17` (tagged as `latest` in env)
- **Config (inside container):** `/home/node/.openclaw/openclaw.json`
- **Workspace (inside container):** `/home/node/.openclaw/workspace/`
- **Hooks (inside container):** `/home/node/.openclaw/hooks/`
- **⚠️ Never use `/opt/openclaw/...` inside the container** – that's the host path, not visible in container.
- **Mounts:** Host `/opt/openclaw/data` → Container `/home/node/.openclaw/`

### Host System (Ubuntu 24.04)
- **OpenClaw data:** `/opt/openclaw/data/` (persistent: config, workspace, logs)
- **OpenClaw binary wrapper:** `/home/node/.openclaw/bin/openclaw` (on host, but not used inside container)
- **Docker containers:** `openclaw-openclaw-gateway-1`, `brain-brain-1`, `n8n-n8n-1`, `chromadb`, etc.

### Important: Container vs Host
- **All OpenClaw CLI commands must be executed inside the container** (`docker exec openclaw-openclaw-gateway-1 ...`)
- **Do NOT run `openclaw` on the host** – it will fail (missing `/app/dist/index.js` on host).
- **Config edits** – edit `/home/node/.openclaw/openclaw.json` *from inside the container* (or edit on host at `/opt/openclaw/data/openclaw.json` and restart container).

## ⚙️ Current Configuration

### Compaction & Memory Flush
- **Version:** 2026.2.17 does **NOT** support `compaction.memoryFlush.sources`
- **Workaround:** Pre-compaction hook that runs `openclaw memory reindex --all` to sync both memory and sessions.
- **Hook installed:** `/home/node/.openclaw/hooks/pre-compaction.sh`
- **Hook registered in config:** `hooks.preCompaction` points to the script.
- **Effect:** Before compaction, all memory sources are reindexed, ensuring fresh data.

### Self-Improvement Skill
- **Installed:** `/home/node/.openclaw/workspace/skills/self-improving-agent/`
- **Logs:** `.learnings/` with LEARNINGS.md, ERRORS.md, FEATURE_REQUESTS.md
- **Hook enabled:** `hooks.internal.entries.self-improvement.enabled: true`
- **Active:** Learnings are automatically extracted from session transcripts.

### Daily Automation
- **Snapshot backup:** Daily at 02:30 (via cron) → GitHub repo `vfranz01/OC_WP_BCK`
- **Self-improvement agent:** Daily at 10:00 AEST (cron) → iterates on workflows.
- **Memory flush:** Enabled (`compaction.memoryFlush.enabled: true`) – only `memory` source; sessions handled by pre-compaction hook.

## 🧠 Second Brain (Dashboard)
- **Container:** `brain-brain-1` (Next.js app)
- **Port:** 3000 (internal), exposed via Traefik
- **URL:** `https://brain.ecomunivers.cloud`
- **Status:** Currently **not running** – `better-sqlite3` bindings missing (musl vs glibc mismatch)
- **DB:** SQLite `brain.db` with FTS + ChromaDB for vector search
- **Fix required:** Rebuild native modules inside brain container with `--build-from-source` or reinstall dependencies as correct user.

## 📦 GitHub Backup
- **Repository:** `vfranz01/OC_WP_BCK`
- **Backup script:** `/home/node/.openclaw/workspace/backup_to_github.sh`
- **Backup content:** Workspace config + Brain source (excluding node_modules, .next, brain.db)
- **Retention:** 7 days (rotating)
- **Cron:** 02:30 daily
- **Auth:** SSH key installed and tested.

## 🔐 Critical Rules
- **Snapshot before any config change** (`scripts/snapshot.sh "reason"`)
- **Never restart OpenClaw unless instructed** – container managed lifecycle.
- **All changes to OpenClaw config** must be done inside container at `/home/node/.openclaw/openclaw.json`.
- **Do not edit files in `/app`** – that's inside the image, not persistent.
- **Always use container paths** when operating inside `openclaw-openclaw-gateway-1`.

## 🚨 Known Issues
- `memoryFlush.sources` not supported in 2026.2.17 → pre-compaction hook workaround active.
- Brain container has broken `better-sqlite3` native binding – needs rebuild.
- `openclaw` CLI on host is non-functional (expects `/app/dist/index.js` on host which doesn't exist).

## 📅 Last Updated
- 2026-02-25 – Added infrastructure details, pre-compaction hook setup, Brain issue diagnosis.

## Über den Club
- Bar mit über 10 deutschen Biersorten
- Deutsche Küche: Schnitzel, Holzfällersteaks, Bratwurst, Gulasch, Spätzle, Chips
- Gemütliche, familiäre Atmosphäre
- Zielgruppe: Locals, Touristen, Deutschsprachige aus DE/AT/CH

## Event Manager — German Club Cairns

### Events abrufen
GET https://n8n.ecomunivers.cloud/webhook/events-get

### Neues Event erstellen
POST https://n8n.ecomunivers.cloud/webhook/events-add
JSON:
{
  "title_en": "Kurzer, einprägsamer Titel auf Englisch",
  "title_de": "Kurzer, einprägsamer Titel auf Deutsch",
  "date": "YYYY-MM-DD",
  "tag_en": "z.B. Dinner | Festival | Live Music | Oktoberfest",
  "tag_de": "z.B. Abendessen | Festival | Livemusik | Oktoberfest",
  "text_en": "SEO-freundlicher Text, 2-3 Sätze. Erwähne deutsche Spezialitäten, Bier, Atmosphäre.",
  "text_de": "SEO-freundlicher Text, 2-3 Sätze. Erwähne deutsche Spezialitäten, Bier, Atmosphäre.",
  "link": "",
  "btn_en": "Table Booking",
  "btn_de": "Tisch reservieren",
  "status": "upcoming"
}
Regeln für gute Texte:
- Titel: kurz, einprägsam, max 5 Wörter
- Tag: immer auf Englisch/Deutsch passend zum Event
- Text: SEO-optimiert, erwähne Atmosphäre, Speisen, Bier
- Button immer "Table Booking" / "Tisch reservieren"
- Frage den User EINMAL ob die Daten stimmen, dann Webhook SOFORT abschicken

### Event löschen
1. Zuerst alle Events abrufen: GET https://n8n.ecomunivers.cloud/webhook/events-get
2. ID des passenden Events finden
3. Löschen: POST https://n8n.ecomunivers.cloud/webhook/events-delete
JSON: { "id": "evt1234567890" }

### Wichtig
- Frage den User MAXIMAL EINMAL ob die Daten stimmen
- Wenn Volker "ja" oder "ok" sagt, schicke den Webhook SOFORT ab ohne weitere Rückfragen
- Frage NICHT mehrfach nach Bestätigung
