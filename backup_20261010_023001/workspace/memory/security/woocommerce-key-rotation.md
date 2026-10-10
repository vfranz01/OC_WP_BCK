---
date: 2026-08-11
title: WooCommerce API key rotation tracker
tags: [security, woocommerce, credentials]
summary: Initial rotation tracking baseline for WooCommerce API keys in TOOLS.md
---

# WooCommerce API Key Rotation

- **Last rotated:** 2026-08-11
- **Key fingerprint (sha256, first 12):** 4685ea404b66
- **Tool:** scripts/rotate_woocommerce_keys.sh
- **Note:** Baseline established from TOOLS.md key definition date (2026-08-11). Run `bash scripts/rotate_woocommerce_keys.sh` when generating new keys to refresh this timestamp.

## 2026-09-01 — Second key pair found & scrubbed from skill file

- Found a **second, untracked WooCommerce key pair** hardcoded in
  `skills/ecomunivers/SKILL.md` (curl example, line 45):
  `ck_2accdf6c...` / `cs_cd5f82a...` (fingerprint `c20f90f4daf2`).
- Replaced with placeholders + pointer to TOOLS.md. Skills are shareable
  artifacts — credentials must never live there.
- **Action for Volker:** verify whether the `ck_2accdf6c...` pair is still in
  use (n8n?). If yes, rotate it; if no, revoke it in WooCommerce → Settings →
  Advanced → REST API. The pair is also present in old backup tarballs
  (backup_repo), so rotation is the real remediation.
- `commit-workspace.sh` now blocks commits containing credential patterns
  (TOOLS.md exempt with warning).
