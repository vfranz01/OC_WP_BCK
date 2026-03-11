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
- **Image:** `ghcr.io/openclaw/openclaw:2026.2.26`
- **Config (inside container):** `/home/node/.openclaw/openclaw.json`
- **Workspace (inside container):** `/home/node/.openclaw/workspace/`
- **Hooks (inside container):** `/home/node/.openclaw/hooks/`
- **⚠️ Never use `/opt/openclaw/...` inside the container** – that's the host path, not visible in container.
- **Mounts:** Host `/opt/openclaw/data` → Container `/home/node/.openclaw/`

### Host System (Ubuntu 24.04)
- **OpenClaw data:** `/opt/openclaw/data/` (persistent: config, workspace, logs)
- **Docker containers:** `openclaw-openclaw-gateway-1`, `brain-brain-1`, `n8n-n8n-1`, `chromadb`, etc.

### Important: Container vs Host
- **All OpenClaw CLI commands must be executed inside the container** (`docker exec openclaw-openclaw-gateway-1 ...`)
- **Do NOT run `openclaw` on the host** – it will fail.
- **Config edits** – edit on host at `/opt/openclaw/data/openclaw.json` and restart container.

## ⚙️ Current Configuration

### LLM Model
- **Primary:** `openrouter/mistralai/mistral-large-2411`
- **Fallback:** `anthropic/claude-3-5-sonnet`
- **OpenRouter:** $10 Guthaben aufgeladen (2026-02-26)

### LLM Providers (config.yaml)
- **OpenRouter:** `https://openrouter.ai/api/v1` → `${OPENROUTER_API_KEY}`
- **Anthropic:** `${ANTHROPIC_API_KEY}` (resets 2026-03-01)
- **NVIDIA:** `https://integrate.api.nvidia.com/v1` → `${NVIDIA_API_KEY}` (Kimi K2.5 available)

### Compaction & Memory
- **Mode:** safeguard
- **memoryFlush:** enabled

### Self-Improvement Skill
- **Installed:** `/home/node/.openclaw/workspace/skills/self-improving-agent/`
- **Hook enabled:** `hooks.internal.entries.self-improvement.enabled: true`
- **⚠️ Warnung:** Kann sich selbst falsch konfigurieren — beobachten!

### Daily Automation
- **Snapshot backup:** Daily at 02:30 (via cron) → GitHub repo `vfranz01/OC_WP_BCK`
- **Self-improvement agent:** Daily at 10:00 AEST

## 🧠 Second Brain (Dashboard)
- **Container:** `brain-brain-1` (Next.js app)
- **URL:** `https://brain.ecomunivers.cloud`
- **Status:** ✅ Läuft — via Cloudflare Tunnel auf Port 3000
- **Issue Resolved (2026-02-26):** `better-sqlite3` bindings mismatch due to musl vs glibc. Fixed by rebuilding native modules inside the container with `npm install --build-from-source`.
- **Mount:** `/opt/openclaw/data` → `/home/node/.openclaw/` im Brain Container
- **DB:** SQLite `brain.db` mit FTS + ChromaDB für vector search

## 📦 GitHub Backup
- **Repository:** `vfranz01/OC_WP_BCK`
- **Backup script:** `/home/node/.openclaw/workspace/backup_to_github.sh`
- **Retention:** 7 days (rotating)
- **Cron:** 02:30 daily

## 🔐 Critical Rules
- **Snapshot before any config change**
- **Never restart OpenClaw unless instructed**
- **Do NOT run `openclaw` directly on host** — immer via `docker exec`
- **Do not edit files in `/app`** – not persistent

---

### 🔐 Pending: Skript-Berechtigungen setzen
Die Skripte für die **tägliche Backup-Validierung** müssen einmalig manuell ausführbar gemacht werden.
**Befehl (Host-Terminal):**
```bash
chmod +x /opt/openclaw/data/workspace/scripts/validate_backup.sh /opt/openclaw/data/workspace/scripts/trigger_backup_snapshot.sh
```
*→ Ohne diese Berechtigung schlägt die Automatisierung fehl.*

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
Regeln:
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
- Wenn Volker "ja" oder "ok" sagt, schicke den Webhook SOFORT ab
- Frage NICHT mehrfach nach Bestätigung

## 📅 Last Updated
- 2026-02-26 — Version update 2026.2.24, Brain läuft wieder, NVIDIA Provider hinzugefügt, OpenRouter aufgeladen
EOF
## 🤖 Agent Routing

### Coder Agent (Kimi K2.5)
- **Agent ID:** coder
- **Modell:** nvidia/moonshotai/kimi-k2.5
- **Workspace:** ~/.openclaw/workspace-coder

### Wann an Coder delegieren?
Wenn Volker folgendes fragt:
- Code schreiben oder debuggen
- Docker Konfiguration ändern
- n8n Workflows erstellen oder anpassen
- Brain Dashboard anpassen
- JavaScript, Python, Shell Scripts
- Webhook Entwicklung

### Wie delegieren?
Nutze das `agents` Tool um die Aufgabe an den Coder Agent weiterzuleiten.
Sage Volker: "Ich leite das an meinen Coding Spezialisten Kimi weiter."
