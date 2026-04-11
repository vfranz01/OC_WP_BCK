# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

## WooCommerce

### digital.ecomunivers.com
- **Consumer Key:** ck_ff625a0fdddb27ead9b4942c166de9f443a4e2ef
- **Consumer Secret:** cs_91199d05bf058072a0ee283807417dc37773fe38
- **API:** /wp-json/wc/v3/
- **Auth:** Basic Auth (Consumer Key:Consumer Secret)
- **Zugang:** curl -u "ck_ff625a0fdddb27ead9b4942c166de9f443a4e2ef:cs_91199d05bf058072a0ee283807417dc37773fe38" "https://digital.ecomunivers.com/wp-json/wc/v3/products?per_page=100"

---

Add whatever helps you do your job. This is your cheat sheet.

## ⚠️ Nach Openclaw Updates
Nach jedem Update prüfen ob curl allowedDomains noch gesetzt ist:
cat /opt/openclaw/data/openclaw.json | python3 -m json.tool | grep -A10 "safeBinProfiles"
Wenn leer → Fix: python3 script in /opt/openclaw-snapshots/v2026.3.28/NOTES.md
