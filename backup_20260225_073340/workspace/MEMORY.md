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
