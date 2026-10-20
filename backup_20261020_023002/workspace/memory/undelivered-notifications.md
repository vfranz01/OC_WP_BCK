---
date: 2026-10-20
title: Undelivered Notifications
tags: ["automation", "incident", "telegram"]
projects: [general]
summary: Generic notification queue — messages a script could not deliver.
---

<!-- undelivered-notifications.md — notifications whose delivery FAILED.
     Written by scripts/notify-queue.py (called from scripts/telegram-send.sh).
     Do not hand-edit entries. Flush after Telegram is restored:
       bash scripts/telegram-send.sh --flush
     Blocker nudges have their own queue: memory/undelivered-nudges.md -->

