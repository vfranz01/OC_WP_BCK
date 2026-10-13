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
- next: Volker re-issues WP app password/API keys + fixes Cloudflare SSL mode (Full/Flexible mismatch) + regenerates Telegram bot token (BotFather -> openclaw.json). TWO drafted posts are queued — outbox/eco-2026-09-21-passive-income-ideas.html and outbox/eco-2026-09-25-how-to-grow-instagram-followers.html — publish both once access works (see scripts/check-outbox.sh). Still blocked as of 2026-10-04 (day 15); Monday blog run failed again.
- 2026-10-11 re-check (Monday run): identical failures. WP REST users/me → 401 rest_not_logged_in; POST /posts (supchief) → 401 rest_cannot_create (auth reaches WP, password rejected). WooCommerce REST cron + TOOLS.md keys → 401; WORKAROUND found: public WP REST `/wp-json/wp/v2/product?product_cat=39|46` + public `/wp-json/wc/store/v1/products` (category param, not product_cat) return product names/URLs/prices fine. DataForSEO → 40200. Post #3 queued in outbox: eco-2026-10-12-how-to-make-money-with-digital-products.{html,json} (1843 words, topic "make money with digital products", product links AI-Powered Profits $29.00 / Digital Product Masterclass $4.95). Cloudflare https→http 301 downgrade persists.
- 2026-10-04 re-check (Monday run): WP REST `users/me` + POST /posts → 401 rest_not_logged_in / rest_cannot_create (https AND http direct, so not redirect-only). Cloudflare https→http 301 downgrade persists. WooCommerce REST (cron ck_bf47… + TOOLS ck_ff62…) → 401 rest_cannot_view. DataForSEO → 40100 unauthorized (no credits). BOTH Telegram bot tokens ('coder', 'default') and env TELEGRAM_BOT_TOKEN → getMe 401. No post published; no post-memory file written (per run rules). Notified via cron delivery only (Telegram itself dead).