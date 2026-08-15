---
date: 2026-08-14
title: Self Improvement Log
tags: [heartbeat", "automation", "incident", "backup", "security]
projects: [general]
summary: Daily Self-Improvement routine. Newest entries at the bottom.
---


# Self-Improvement Log

Dated, traceable record of workflow improvements made during the
Daily Self-Improvement routine. Newest entries at the bottom.


## 2026-08-12 — Daily self-improvement logging

Added scripts/log-self-improvement.sh and memory/self-improvement-log.md.

Before: daily_self_improvement.md was a single stale entry (2026-05-27) with no way to trace changes across days.

Now: each Daily Self-Improvement run can append a dated, titled entry to memory/self-improvement-log.md (stdin or second arg accepted), keeping the history audit-friendly. Updated daily_self_improvement.md to point at the new log.

## 2026-08-13 — WooCommerce key rotation tracking + heartbeat staleness check

TOOLS.md reminds us to rotate WooCommerce API keys "regularly", but nothing tracked the last rotation — so staleness was invisible.

Added:
- scripts/check_woocommerce_key_age.sh — reads memory/security/woocommerce-key-rotation.md and flags keys older than 90 days (env-overridable via WOOKEY_MAX_AGE_DAYS). 0 = fresh, non-zero = overdue/missing.
- scripts/rotate_woocommerce_keys.sh — now records the rotation date + a sha256 key fingerprint (first 12 chars) to memory/security/woocommerce-key-rotation.md. Only the date/fingerprint is stored, never the secrets, so the tracker is safe to back up.
- scripts/health-quick-check.sh — new check #7 wires the age check into the heartbeat routine so stale API keys surface automatically.

Next step (manual, external): run rotate_woocommerce_keys.sh, update n8n/integrations, revoke old keys.

## 2026-08-14 — Disk-space check wired into heartbeat health check

check_disk_space.sh existed but was never invoked — silent risk: full-disk failures
(backup writes, memory corruption, DB bloat) would go unnoticed.

Added:
- scripts/health-quick-check.sh — new check #8 runs check_disk_space.sh, flags
  WARN (>=90%) and CRITICAL (>=95%) usage as health issues instead of ignoring it.
- Health-check exit code now surfaces disk problems automatically during heartbeat.

Note: the two current health-check warnings (memory frontmatter, WooCommerce key
rotation untracked) are pre-existing manual follow-ups, not caused by this change.

## 2026-08-15 — Health check auto-repairs missing memory frontmatter

validate-memory-files.sh could fail, but the fixer scripts/fix-memory-frontmatter.sh existed
(backup-safe, only touches files lacking frontmatter) and was never invoked — so every
heartbeat re-reported the same repair-ready warning as a blocking issue.

Added to scripts/health-quick-check.sh (check #5):
- On validation failure, automatically run fix-memory-frontmatter.sh, then re-validate.
- Reports "auto-repaired" when the fix succeeds; only counts the issue when both
  repair and revalidation fail.
- The still-open WooCommerce key rotation warning is a manual/external follow-up
  (run rotate_woocommerce_keys.sh, update n8n), not affected by this change.
