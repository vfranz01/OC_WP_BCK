---
date: 2026-09-21
title: Blockers
tags: ["heartbeat", "blog", "ecomunivers", "incident"]
projects: [general]
summary: Open Blockers
---


# Open Blockers

<!-- One block per item. Example:
## YYYY-MM-DD — Short title
- status: open          (or resolved)
- waiting_on: user      (user | external | mux)
- next: Exact next action to unblock
Set `status: resolved` when done — check-blockers.sh only reports 'open' items.
-->

## 2026-09-20 — Ecomunivers Monday post blocked (WP auth + Cloudflare SSL)
- status: open
- waiting_on: user
- next: Volker re-issues WP app password/API keys + fixes Cloudflare SSL mode (Full/Flexible mismatch) + regenerates Telegram bot token (BotFather -> openclaw.json). TWO drafted posts are queued — outbox/eco-2026-09-21-passive-income-ideas.html and outbox/eco-2026-09-25-how-to-grow-instagram-followers.html — publish both once access works (see scripts/check-outbox.sh). Still blocked as of 2026-10-01 (day 13); Friday blog run failed again.