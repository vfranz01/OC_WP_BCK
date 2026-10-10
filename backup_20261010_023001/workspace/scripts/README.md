# Scripts Documentation

This directory contains automation scripts for workspace management, backup, validation, and deployment tasks. All scripts are executable.

---

## 🔧 Cron Setup (CRITICAL FIRST STEP)

### `HOST-SETUP-CRON.sh` ⭐ NEW
**Purpose:** Install all automated maintenance jobs on the host (Hostinger VPS) crontab. **Run this first** to enable daily backups, health checks, and safety audits.

**Important:** This script MUST run on the HOST (Hostinger VPS), not inside Docker.

**Usage on VPS host:**
```bash
bash /home/node/.openclaw/workspace/scripts/HOST-SETUP-CRON.sh
```

**What it installs:**
- 02:30 UTC: Daily snapshot (GitHub backup)
- 03:00 UTC: Daily health quick-check
- 04:00 UTC: Curl domain validation
- 05:00 UTC: Backup validation
- 12:00 UTC: Daily status summary
- 14:00 UTC (Mon/Wed/Fri): Blog post validation
- 10:00 UTC (Sundays): Weekly safety audit

**Returns:**
- `0` = All jobs installed successfully (or already exist)
- Logs all actions to `memory/cron-install.log`
- Creates backup of existing crontab (if any)

**Integration:**
- **One-time setup** — run once to activate all automation
- Safe to run multiple times (idempotent — skips existing jobs)
- All jobs use `docker exec` to run inside container
- Logs go to `memory/` directory for review

---

### `install-cron-jobs.sh` (Deprecated)
Legacy script for container crontab (no longer used since crontab not available in container). Kept for reference.

---

## 🔄 Backup & Snapshot Scripts

### `snapshot.sh`
**Purpose:** Create a timestamped backup of all critical OpenClaw configuration and data files to GitHub.

**Usage:**
```bash
bash snapshot.sh "commit message describing the change"
```

**Parameters:**
- `$1`: Commit message (required) — describes what changed and why

**Integration:**
- Called before any critical config changes (per MEMORY.md rules)
- Scheduled daily at 02:30 UTC via cron
- Uploads to GitHub repo: `vfranz01/OC_WP_BCK`
- Updates `memory/last_snapshot.txt` by calling `scripts/snapshot_log.sh` relative to the workspace scripts directory

**Typical use:**
```bash
bash snapshot.sh "Fixed blog post timezone issue"
bash snapshot.sh "Updated n8n webhook configuration"
```

---

### `snapshot_stopgap.sh` ⭐
**Purpose:** Keep the local daily backup chain alive until the real host crontab (`HOST-SETUP-CRON.sh`, 02:30 UTC job) is installed. Both install paths are blocked from inside the container (cron tool is restricted in cron sessions; no crontab on the container), so the daily `02:30` snapshot would otherwise rot.

**Usage:**
```bash
bash snapshot_stopgap.sh            # create a fresh daily_auto_snapshot if the chain is stale
bash snapshot_stopgap.sh --quiet    # only print when it actually created one
```

**Behavior:**
- Idempotent and `flock`-guarded (safe under concurrent heartbeats)
- Runs at most once per 23h window; no-op while the chain is fresh
- Written by `health-quick-check.sh` (check #9) so staleness self-heals at the first failing check

**Integration:**
- Called by `health-quick-check.sh` and `daily-status-summary.sh`
- If it fails, the staleness alert still fires — no silent failure masking

---

### `validate_backup.sh`
**Purpose:** Verify the latest GitHub backup exists, is recent, and accessible. Returns exit code 0 (success) or non-zero (failure).

**Usage:**
```bash
bash validate_backup.sh
if [ $? -ne 0 ]; then
  echo "Backup validation failed!"
  bash trigger_backup_snapshot.sh
fi
```

**Returns:**
- `0` = Backup exists and is recent (< 48 hours)
- `1` = Backup missing, corrupted, or too old

**Integration:**
- Part of HEARTBEAT checks (run multiple times daily)
- Logs failures to `memory/backup_incidents.log`
- Automatically rotates log when it exceeds 500 lines (prevents unbounded growth)
- If validation fails, should trigger `trigger_backup_snapshot.sh`

---

### `trigger_backup_snapshot.sh`
**Purpose:** Immediately create a backup snapshot, bypassing timestamp checks. Used when validation fails or emergency backup is needed.

**Usage:**
```bash
bash trigger_backup_snapshot.sh
```

**Integration:**
- Called only when `validate_backup.sh` returns failure
- Logs actions to `memory/backup_incidents.log`
- Useful for manual emergency backups

---

### `backup_monitor.sh`
**Purpose:** Monitor and report on backup status trends over time. Shows validation history and incident frequency.

**Usage:**
```bash
bash backup_monitor.sh
```

**Integration:**
- Standalone monitoring utility
- Can be run manually to audit backup health
- Reads from `memory/backup_incidents.log`

---

### `backup_validation_with_notification.sh`
**Purpose:** Combined validation + notification wrapper. Checks backup and sends alerts on failure.

**Usage:**
```bash
bash backup_validation_with_notification.sh
```

**Integration:**
- Legacy script; prefer direct `validate_backup.sh` + incident logging
- Referenced in cron but newer heartbeat uses simpler approach

---

### `restore.sh`
**Purpose:** Restore OpenClaw from a timestamped snapshot backup. **Use with care — this overwrites current config.**

**Usage:**
```bash
bash restore.sh
```

⚠️ **WARNING:** Restores from GitHub backup. Only use if instructed by Volker. Will overwrite current `/home/node/.openclaw/` contents.

---

### `backup_github_sync.sh`
**Purpose:** Push new backup archives to the GitHub backup repo. Runs as root on the host (Hostinger VPS) using an SSH key.

**Usage:**
```bash
bash backup_github_sync.sh
```

**Integration:**
- Host-side half of the 02:30 UTC backup pipeline
- Referenced by `validate_backup.sh` / `health-quick-check.sh` indirectly through `logs/backup.log`

---

### `backup_restore.sh`
**Purpose:** Pull backup archives from GitHub and restore them. Runs as root on the host.

**Usage:**
```bash
bash backup_restore.sh
```

**Integration:**
- Host-side recovery counterpart to `backup_github_sync.sh`
- Manual recovery only; prefer `restore.sh` for in-container restores

---

## ✅ Validation Scripts

### `validate_backup.sh`
(See Backup section above)

---

### `validate_critical_rules.sh`
**Purpose:** Audit critical rules defined in `MEMORY.md` against actual system state. Ensures safety rules are being followed.

**Usage:**
```bash
bash validate_critical_rules.sh
```

**Validates:**
- Backup exists and is recent
- OpenClaw config file is readable
- Critical paths exist
- No dangerous operations in progress

**Integration:**
- Can be run on-demand for safety audits
- Helps verify system health after changes

---

### `validate_blog_job.sh`
**Purpose:** Check if the T-ShirtBull blog cron job ran successfully on scheduled days (Mon/Wed/Fri).

**Usage:**
```bash
bash validate_blog_job.sh
```

**Reads:**
- `memory/YYYY-MM-DD.md` for blog post publication entries
- System logs and cron history

**Integration:**
- Part of HEARTBEAT checks (runs only on Mon/Wed/Fri)
- Helps verify daily blog post workflow is functioning

---

### `create_daily_memory_file.sh`
**Purpose:** Idempotently create `memory/YYYY-MM-DD.md` with proper frontmatter and body sections. Safe to run from any working directory.

**Usage:**
```bash
bash /home/node/.openclaw/workspace/scripts/create_daily_memory_file.sh
bash /home/node/.openclaw/workspace/scripts/create_daily_memory_file.sh 2026-06-17  # optional date for tests/backfill
```

**Behavior:**
- Resolves workspace paths relative to the script, not the caller's current directory
- Uses `memory/template.md` when available, with fallback content if the template is missing
- Writes via a temporary file + atomic rename to avoid half-written daily logs
- Validates optional dates as `YYYY-MM-DD`
- Ensures daily logs are never frontmatter-only

**Integration:**
- Called at session start and by `daily-status-summary.sh`
- Prevents duplicate or misplaced `memory/` folders when automation runs from cron, Docker, or manual shells

---

### `weekly-safety-audit.sh` ⭐ NEW
**Purpose:** Comprehensive weekly safety audit combining multiple validations. Ensures critical rules remain in place and system health is maintained.

**Usage:**
```bash
bash weekly-safety-audit.sh
```

**Checks:**
1. ✅ Critical rules validation (from MEMORY.md)
2. ✅ File permission security
3. ✅ Backup system health
4. ✅ Memory structure and size (`MEMORY.md` target: ≤ 5000 bytes)

**Automatic memory hygiene:**
- Raw `## Promoted From Short-Term Memory` blocks are moved to `memory/promoted-memory-archive.md`
- `compact-memory-promotions.sh` creates a timestamped backup before changing `MEMORY.md`
- If the curated file remains above the target after compaction, the audit fails with an actionable manual-distillation warning
- `WORKSPACE_DIR`, `AUDIT_LOG`, and `MEMORY_MAX_BYTES` can be overridden for testing

**Creates:**
- Detailed audit log at `memory/weekly-safety-audit.log`
- Searchable historical record of all audits

**Returns:**
- `0` = All checks pass
- `1` = Issues found (review log)

**Recommended:** Run once per week (e.g., Sundays) as part of periodic review workflow.

---

### `check_validation_status.sh`
**Purpose:** Display a status report of recent validation checks and any incidents logged.

**Usage:**
```bash
bash check_validation_status.sh
```

**Output:**
- Shows validation trend (success/failure frequency)
- Recent incidents from `memory/backup_incidents.log`
- Timestamp of last successful backup

**Integration:**
- Manual diagnostic tool for system health
- Can be run during troubleshooting

---

### `check_curl_allowed_domains.sh`
**Purpose:** Verify that curl `allowedDomains` configuration is properly set in OpenClaw config after updates.

**Usage:**
```bash
bash check_curl_allowed_domains.sh
```

**Checks:**
- OpenClaw JSON config file for curl allowedDomains setting
- Alerts if domains list is empty or missing after update

**Integration:**
- Part of heartbeat checks (runs daily)
- Ensures external API calls continue working after OpenClaw upgrades

---

### `check_disk_space.sh`
**Purpose:** Monitor the root partition for high disk usage. Exit codes: `0` = OK, `2` = warning (≥ warn threshold), `1` = critical/unknown, so a 90–94% disk is not reported as healthy.

**Usage:**
```bash
bash check_disk_space.sh
```

**Integration:**
- Wired into `health-quick-check.sh` (check #8)
- Thresholds overridable via env for testing

---

### `check-blockers.sh`
**Purpose:** Surface open blockers from `memory/blockers.md` (items waiting on Volker/external fixes). Fresh blockers (<24h) are informational; stale ones (>24h) count as an issue so blocked work stays visible instead of rotting in daily memory.

**Usage:**
```bash
bash check-blockers.sh
```

**Returns:**
- `0` = no open blockers (or only fresh ones)
- `1` = at least one open blocker older than 24h

**Integration:**
- Wired into `health-quick-check.sh` (check #10)
- Blocker file format: one `## YYYY-MM-DD — title` block with `status:`, `waiting_on:`, `next:` lines

---

### `check-outbox.sh`
**Purpose:** Inventory drafts waiting in `outbox/` for publication. Drafts can fall off the blockers list and sit forgotten for days, so this surfaces them with age + intended publish date (parsed from `eco-YYYY-MM-DD-*` filenames).

**Usage:**
```bash
bash check-outbox.sh            # default threshold 3 days
bash check-outbox.sh --days 30  # custom overdue threshold
bash check-outbox.sh --quiet    # silent when nothing is overdue
```

**Returns:**
- `1` only signals "something overdue" — informational, never fails a cron

**Integration:**
- Wired into `daily-improve-context.sh` (section: Outbox / pending drafts)

---

### `check_telegram_token.sh`
**Purpose:** Verify every Telegram bot token via the side-effect-free `getMe` endpoint. Outbound sends fail with `401` when a token in `openclaw.json` is revoked/stale, and Telegram is the only comms channel to Volker — so this surfaces outages immediately instead of days late. **Recovery is delivery-verified:** when a previously-failing check finds valid tokens, it runs a one-shot silent `sendMessage` smoke test to Volker's chat (`TELEGRAM_CHAT_ID` env override, default 881022003) and only clears the outage streak if Telegram confirms `ok:true`. A valid token with failing delivery is reported as "token valid but delivery failing" (exit 1) instead of a false recovery.

**Usage:**
```bash
bash check_telegram_token.sh
```

**Returns:**
- `0` = all tokens valid
- `1` = at least one token unauthorized (regen via @BotFather)
- `2` = no token / config unreadable / network error

**Integration:**
- Wired into `health-quick-check.sh` (check #11)
- Counts consecutive failed days in `memory/telegram-outage.state` and escalates to 🚨 CRITICAL at day 3+; prints a nudge-backlog flush reminder on recovery
- `health-quick-check.sh` (check #11) greps its `⚠️`/`🚨` lines (not `head`) so the CRITICAL outage day-count always survives into the health summary and `daily-improve-context.sh` brief
- Checks the gateway `TELEGRAM_BOT_TOKEN` env override first (it beats the config token)

---

### `check_woocommerce_key_age.sh`
**Purpose:** Verify WooCommerce API keys were rotated recently (within 90 days).

**Usage:**
```bash
bash check_woocommerce_key_age.sh
```

**Returns:**
- `0` = OK (rotated within 90 days)
- non-zero = rotation overdue/missing

**Integration:**
- Wired into `health-quick-check.sh` (check #7) to catch stale credentials proactively

---

### `rotate_backup_log.sh`
**Purpose:** Automatically rotate `backup_incidents.log` when it exceeds 500 lines, preventing unbounded growth. Archives old entries with timestamps, keeps recent entries for quick access.

**Usage:**
```bash
bash rotate_backup_log.sh
```

**Behavior:**
- Monitors `memory/backup_incidents.log` size
- When line count > 500, moves log to `memory/backup_logs/` with timestamp
- Creates fresh active log
- Automatically deletes archives older than 90 days

**Integration:**
- Called automatically by `validate_backup.sh` before appending new entries
- No manual intervention needed — fully automatic
- Preserves all validation history in compressed archives

---

### `backup_log_summary.sh`
**Purpose:** Display a quick health summary of backup validation without reading massive log file. Shows recent entries, pass/fail counts, and archive status.

**Usage:**
```bash
bash backup_log_summary.sh
```

**Output:**
- Last 5 validation results
- Count of recent warnings/failures/passes
- Archive statistics (oldest/newest archived logs)
- Quick status check

**Integration:**
- Manual diagnostic tool for audit trail review
- Can be run anytime to check backup health at a glance
- Much faster than reading the full incident log

---

## 📝 Content & Project Scripts

### `create_tshirtbull_blog_post.sh`
**Purpose:** Validate the scheduled T-ShirtBull blog workflow and write an auditable marker to today's memory log. Publishing is intentionally marked TODO until Shopify API logic is implemented.

**Usage:**
```bash
bash create_tshirtbull_blog_post.sh Fr
bash create_tshirtbull_blog_post.sh Freitag
```

**Parameters:**
- `$1`: Scheduled day (`Mo`/`Montag`, `Mi`/`Mittwoch`, `Fr`/`Freitag`)

**Integration:**
- Called by blog automation workflows (Mondays/Wednesdays/Fridays at 9:00 AEST)
- Ensures today's memory file exists before appending
- Logs planned blog type and Shopify Blog ID without falsely claiming publication

---

### `check_tshirtbull_blogpost.sh`
**Purpose:** Verify that today's scheduled T-ShirtBull blog post was successfully published.

**Usage:**
```bash
bash check_tshirtbull_blogpost.sh
```

**Returns:**
- `0` = Post published successfully
- `1` = Post not found or publish failed

**Integration:**
- Part of HEARTBEAT checks (Mon/Wed/Fri only)
- Logs results to memory for validation
- Alerts if blog job didn't run as expected

---

## 🔧 Utility & Infrastructure Scripts

### `replace_skills.sh`
**Purpose:** Utility to update or replace skill files in the workspace.

**Usage:**
```bash
bash replace_skills.sh [skill_name]
```

**Integration:**
- Manual maintenance tool
- Used when skills need version updates or fixes

---

### `commit-workspace.sh`
**Purpose:** Safe single-command git commit of workspace docs, memory and scripts. Stages only allow-listed paths, refuses secrets and `.pyc` by construction, and never pushes.

**Usage:**
```bash
bash commit-workspace.sh "chore: describe the change"
```

**Integration:**
- Called by `health-quick-check.sh` (check #13) to checkpoint substantive uncommitted changes between sessions
- Idempotent: no-op when the tree is clean

---

### `check_cron_job.sh`
**Purpose:** Verify that a specific cron job is scheduled and functional.

**Usage:**
```bash
bash check_cron_job.sh [job_name]
```

**Integration:**
- Diagnostic tool for cron troubleshooting
- Used to verify scheduled tasks are set up correctly

---

### `validate-all-cron-jobs.sh`
**Purpose:** Check that all 7 documented automation jobs are scheduled and healthy.

**Usage:**
```bash
bash validate-all-cron-jobs.sh
```

**Returns:**
- `0` = all good
- `1` = issues detected

**Integration:**
- Wired into `health-quick-check.sh` (check #6, only on systems with `crontab`)
- Used by daily monitoring dashboards

---

### `run-on-boot.sh`
**Purpose:** Ensure OpenClaw Brain container is running on system startup.

**Usage:**
```bash
#!/bin/bash
docker exec openclaw-openclaw-gateway-1 bash /home/node/.openclaw/workspace/brain/ensure-running.sh
```

**Integration:**
- Called from system startup scripts / rc.local
- Ensures Brain Dashboard container survives server reboots

---

## 🩺 Health & Status Scripts

### `daily-status-summary.sh`
**Purpose:** Create/update daily memory log with consolidated health checks. Resumes daily logging habit and provides structured status tracking.

**Usage:**
```bash
bash daily-status-summary.sh
```

**Creates:**
- Daily memory entry at `memory/YYYY-MM-DD.md`
- Appends status checks with timestamps
- Logs backup health, critical files, system state
- Runs the learnings-sync reminder once only (marker: `memory/.learnings_run`)

**Safety notes:**
- Gateway uptime check is best-effort: if the `openclaw` CLI is unavailable in the runtime, the script logs an informational skip instead of failing the daily summary.
- Gateway status failures are written to `memory/backup_incidents.log` with a timestamp for later review.
- Blog post check uses only Python standard-library HTTP (`urllib`), so it works even when the optional `requests` package is not installed.

**Integration:**
- **Recommended: Run during heartbeats** (1-2x daily) to maintain daily logs
- Non-intrusive, fast execution
- Helps track system trends and catch issues early

---

### `health-quick-check.sh`
**Purpose:** Fast health probe for heartbeat use. Single-command system status overview.

**Usage:**
```bash
bash health-quick-check.sh && echo "All good" || echo "Issues detected"
```

**Checks (13 total):**
1. ✅ Backup system operational (`validate_backup.sh`)
2. ✅ All critical files present (MEMORY/AGENTS/TOOLS/SOUL/USER)
3. ✅ Scripts executable
4. ✅ Daily memory files present (today + yesterday) — self-heals via `ensure_daily_memory.sh`
5. ✅ Memory file format valid — self-heals via `fix-memory-frontmatter.sh`
6. ✅ Cron jobs healthy (`validate-all-cron-jobs.sh`, only where `crontab` exists)
7. ✅ WooCommerce API key freshness (`check_woocommerce_key_age.sh`)
8. ✅ Disk space (`check_disk_space.sh`)
9. ✅ Daily snapshot freshness — only accepts `daily_auto_snapshot`; self-heals via `snapshot_stopgap.sh`; off-machine GitHub backup verified before alarming
10. ✅ Open blockers (`check-blockers.sh`) — stale (>24h) counts as an issue
11. ✅ Telegram bot tokens (`check_telegram_token.sh`) — outage escalation
12. ✅ Memory index freshness (`memory/index.md`) — self-heals via `update-memory-index.py`
13. ✅ Workspace git checkpoint — self-heals via `commit-workspace.sh` (noise-aware; disable with `HEALTH_NO_AUTOCOMMIT=1`)

**Returns:**
- `0` = All systems healthy
- `non-zero` = Issues detected (review logs)

**Integration:**
- Quick check before major tasks
- Condition for running critical operations
- Can be used in automation pipelines
- Now includes memory file validation (as of 2026-05-12)

---

### `validate-memory-files.sh` ⭐ NEW
**Purpose:** Ensure all memory files in `memory/` follow the documented YAML frontmatter format. Validates consistency and flags issues.

**Usage:**
```bash
bash validate-memory-files.sh
```

**Validates:**
- ✅ All `.md` files have YAML frontmatter (date, title, tags, projects, summary)
- ✅ Frontmatter is properly closed with `---`
- ✅ Files have content beyond frontmatter (not just headers)
- ⏱️ Detects stale files (older than 7 days without updates)

**Returns:**
- `0` = All memory files valid
- `non-zero` = Format issues detected

**Integration:**
- Integrated into `health-quick-check.sh` (runs automatically)
- Helps maintain memory system consistency
- Essential for reliable memory dashboards and exports

**Output example:**
```
✅ 2026-05-11.md
⚠️  2026-04-15.md - Has frontmatter but minimal body
❌ 2026-03-30.md - Missing YAML frontmatter
⏱️  2026-02-18.md - Last modified 44 days ago

✅ Valid format: 76
❌ Missing frontmatter: 0
⏱️  Stale (>7 days): 35
```

---

### `fix-memory-frontmatter.sh` ⭐ NEW
**Purpose:** Automatically add missing YAML frontmatter to memory files. Uses smart heuristics to extract date, title, tags from filename and content analysis.

**Usage:**
```bash
bash fix-memory-frontmatter.sh
```

**Features:**
- 🔍 Extracts date from filename (YYYY-MM-DD format); falls back to file modification date for undated helper notes
- 📝 Generates title from filename or content, including snake_case and kebab-case names
- 🏷️ Auto-detects tags based on content keywords (heartbeat, blog, tshirtbull, etc.)
- 📄 Pulls first substantive line as summary (max 80 chars)
- 💾 Creates backups of original files in `memory/.backups/`
- 🛡️ Safe: no destructive actions without backup

**Parameters:**
- None — automatically processes all files needing frontmatter

**Integration:**
- One-time maintenance tool (applied 2026-05-12 and re-run 2026-06-17)
- Can be re-run safely to update inconsistent files
- Creates backups for recovery if needed
- Keeps `validate-memory-files.sh` from failing forever on undated memory helper notes like `daily_self_improvement.md`

**Example result:**
```yaml
---
date: 2026-04-15
title: Tshirtbull Mittwoch
tags: [tshirtbull, blog]
projects: [tshirtbull]
summary: Blog post analysis and content planning
---

[original content...]
```

**Recent run (2026-05-12):**
- Fixed 35 files with missing frontmatter
- Created backups for all originals in `memory/.backups/`
- Skipped 3 special index files (manually fixed separately)
- Result: 100% of memory files now valid

---

### `sync-learnings.sh` ⭐ NEW
**Purpose:** Auto-scan recent memory files and suggest learnings to capture in `.learnings/` directory. Keeps learnings knowledge base up-to-date with minimal manual effort.

**Usage:**
```bash
bash sync-learnings.sh [--auto] [--days N]
```

**Parameters:**
- `--auto` — Auto-capture mode (recommended for cron, less interactive)
- `--days N` — Look back N days (default: 7)

**Examples:**
```bash
bash sync-learnings.sh              # Interactive, last 7 days
bash sync-learnings.sh --days 30    # Interactive, last 30 days
bash sync-learnings.sh --auto       # Auto-capture mode, last 7 days
```

**What it does:**
1. 🔍 Scans recent memory files (last N days)
2. 🏷️ Looks for tagged improvements ([improvement], [bug-fix], [critical])
3. 📊 Reports statistics (current learnings count)
4. ✅ Suggests new entries to capture
5. 💾 Auto-mode: Appends summary to `.learnings/LEARNINGS.md`

**Integration:**
- Part of weekly maintenance workflow
- Can be run manually anytime to review recent improvements
- Recommended: Add to weekly cron (e.g., Sundays) for automatic sync
- Reduces manual effort of keeping learnings up-to-date

**Output example:**
```
🧠 Syncing Recent Learnings...
   Looking back 7 days

📊 Current Status:
   - LEARNINGS.md: 8 entries
   - ERRORS.md: 2 entries

✅ Auto-synced: Updated LEARNINGS.md
```

---

## 🧠 Self-Improvement & Context Scripts

### `daily-improve-context.sh`
**Purpose:** One-shot context brief for the daily self-improvement cron (and any session asking "what should I improve today?").

**Usage:**
```bash
bash scripts/daily-improve-context.sh
```

**Prints:**
1. Recent self-improvement entries (so the same fix isn't repeated)
2. Open blockers + ready-to-send nudge reminders + today's nudge outcomes
3. Outbox drafts pending publication
4. Git workspace dirtiness
5. Currently failing `health-quick-check.sh` lines
6. Recent open entries from `.learnings/ERRORS.md`

**Integration:**
- Entry point for the Daily Self-Improvement routine (per AGENTS.md)
- Always exits `0` — informational brief, never fails a cron run

---

### `log-self-improvement.sh`
**Purpose:** Append a dated entry to `memory/self-improvement-log.md` so daily workflow improvements are traceable.

**Usage:**
```bash
bash log-self-improvement.sh "2026-10-05 — Title" "What changed and why"
```

**Integration:**
- Part of the Daily Self-Improvement routine (write-up after each improvement)
- Consumed by `daily-improve-context.sh` to avoid repeating fixes
- Auto-runs `sync-agents-improvements.sh` after each write so AGENTS.md's "Recent Improvements" list never lags the log (prevents the daily drift-guard flag)

---

### `distill-learnings.sh`
**Purpose:** Distill potential learnings (error messages, workarounds, significant events) from recent daily memory logs into candidate `MEMORY.md` entries.

**Usage:**
```bash
bash distill-learnings.sh
```

**Integration:**
- Outputs to stdout for review + manual promotion
- Complements `sync-learnings.sh`

---

### `ensure_self_improvement_reminder.sh`
**Purpose:** Ensure `SELF_IMPROVEMENT_REMINDER.md` exists with the standard content (idempotent).

**Usage:**
```bash
bash ensure_self_improvement_reminder.sh
```

---

### `update-heartbeat-state.sh`
**Purpose:** Stamp `memory/heartbeat-state.json` with the current timestamp for the checks a heartbeat just ran. Makes the documented heartbeat tracker real (it previously sat stale).

**Usage:**
```bash
bash update-heartbeat-state.sh [check_name ...]
```

**Integration:**
- Safe to run on every heartbeat (idempotent state-file update)

---

### `daily-heartbeat-routine.sh`
**Purpose:** Consolidated heartbeat routine (quick health check + daily memory log update) that replaces the raw command list previously inlined in AGENTS.md.

**Usage:**
```bash
bash daily-heartbeat-routine.sh
```

---

### `run_daily_heartbeat.sh`
**Purpose:** Thin launcher that runs the daily heartbeat routine with logging (used by scheduled/automation entry points).

**Usage:**
```bash
bash run_daily_heartbeat.sh
```

---

### `ensure_daily_memory.sh`
**Purpose:** Ensure today's and yesterday's `memory/YYYY-MM-DD.md` exist, creating them if missing. Session prerequisite per AGENTS.md; fails loudly if a file cannot be created.

**Usage:**
```bash
bash ensure_daily_memory.sh
```

**Integration:**
- Enforced by `health-quick-check.sh` (check #4) so a missing daily file self-heals

---

### `nudge-blockers.sh`
**Purpose:** Turn stale `waiting_on: user` blockers into short, ready-to-send reminder texts for Volker.

**Usage:**
```bash
bash nudge-blockers.sh            # blockers stale >48h
bash nudge-blockers.sh --days N   # custom threshold (hours)
bash nudge-blockers.sh --all      # include fresh blockers
bash nudge-blockers.sh --record sent|failed   # record today's delivery outcome
```

**Behavior:**
- Successful sends are deduped in `memory/nudge-state.log` (max 1 nudge/day)
- Failed attempts are NOT deduped — they keep reappearing so delivery is retried

**Integration:**
- Wired into `daily-improve-context.sh` (section: Blocker nudges)

---

### `rotate_woocommerce_keys.sh`
**Purpose:** Document the WooCommerce API key rotation steps and generate a new key pair for updating integrations.

**Usage:**
```bash
bash rotate_woocommerce_keys.sh
```

**Integration:**
- Referenced from TOOLS.md security reminder; update all integrations + revoke old keys after running

---

### `check-scripts-doc.sh` ⭐
**Purpose:** Detect scripts that are missing from this README. Prevents the docs from silently drifting behind the code (as they did for ~5 months, hiding 20 scripts).

**Usage:**
```bash
bash scripts/check-scripts-doc.sh          # report + exit code
bash scripts/check-scripts-doc.sh --quiet  # exit code only
bash scripts/check-scripts-doc.sh --list   # one filename per line
```

**Returns:**
- `0` = every script documented
- `1` = at least one script missing from README.md
- `2` = README.md not found

**Integration:**
- Wired into `daily-improve-context.sh` (section: Script docs drift)

---

### `sync-agents-improvements.sh` ⭐
**Purpose:** Keep AGENTS.md's "Recent Improvements" list in sync with `memory/self-improvement-log.md` (the canonical log appended by `log-self-improvement.sh`). Before this, the list was hand-maintained and silently drifted (observed 2026-10-07: frozen at 2026-09-28 while 7 newer entries existed, plus a stray `^` typo) — and AGENTS.md is loaded into every session, so a stale list actively hides recent automation.

**Usage:**
```bash
bash scripts/sync-agents-improvements.sh           # rewrite list if stale
bash scripts/sync-agents-improvements.sh --limit N # keep N newest (default 12)
bash scripts/sync-agents-improvements.sh --check   # report-only; exit 1 = drift
```

**Returns:**
- `0` = in sync (or successfully synced)
- `1` = `--check` found drift
- `2` = section/log missing or unwritable (nothing modified)

**Integration:**
- Wired into `daily-improve-context.sh` (section: AGENTS.md improvements drift)
- Section-scoped + idempotent: only the bullet block under `## Recent Improvements` is rewritten; heading, blank lines, and all other AGENTS.md content are preserved.

---

### `memory-hygiene.sh` ⭐
**Purpose:** Keep `memory/` free of stale artifacts — accumulated `.bak`/`.tmp`/`.old`/`.orig` backups and test leftovers (`test.txt`, `test_write.txt`, …). Before this (observed 2026-10-10): 13 `.bak` files from Feb/Mar 2026 plus two test files sat in `memory/` for 6+ months, polluting every backup, snapshot, and directory listing.

**Usage:**
```bash
bash scripts/memory-hygiene.sh           # report mode; exit 1 = stale files found
bash scripts/memory-hygiene.sh --apply   # archive stale files → memory/archive/
STALE_DAYS=14 bash scripts/memory-hygiene.sh --apply   # custom age threshold (default 30)
```

**Safety:**
- 🛡️ NEVER deletes — apply mode only moves to `memory/archive/` (created on demand)
- Scans top level of `memory/` only; subdirectories (`dreaming/`, `security/`, `archive/`) untouched
- Active files (`.log`, `*.state`, `*.json`) never matched
- Idempotent: re-run after apply reports clean

**Integration:**
- Wired into `weekly-safety-audit.sh` (step 4b, report-only) so stale artifacts surface in the weekly audit with a one-liner fix command

---

## 📊 Script Dependency Map

```
Cron Setup (HOST-level automation)
└── HOST-SETUP-CRON.sh (ONE-TIME: installs 7 automated jobs on host crontab)
    ├── 02:30 UTC: snapshot.sh → GitHub backup
    ├── 03:00 UTC: health-quick-check.sh
    ├── 04:00 UTC: check_curl_allowed_domains.sh
    ├── 05:00 UTC: validate_backup.sh
    ├── 12:00 UTC: daily-status-summary.sh
    ├── 14:00 UTC (Mon/Wed/Fri): check_tshirtbull_blogpost.sh
    └── 10:00 UTC (Sundays): weekly-safety-audit.sh

Daily/Scheduled Automation (installed via HOST-SETUP-CRON.sh)
├── health-quick-check.sh (daily 03:00 UTC)
│   ├── validate_backup.sh
│   │   ├── rotate_backup_log.sh (automatic log rotation)
│   │   └── (fails) → trigger_backup_snapshot.sh
│   ├── Critical file checks
│   └── Script executability checks
├── daily-status-summary.sh (daily 12:00 UTC)
├── check_curl_allowed_domains.sh (daily 04:00 UTC)
├── validate_backup.sh (daily 05:00 UTC)
└── check_tshirtbull_blogpost.sh (Mon/Wed/Fri 14:00 UTC)

Weekly Safety Audits
└── weekly-safety-audit.sh (Sundays 10:00 UTC)
    ├── validate_critical_rules.sh
    ├── File permission checks
    ├── validate_backup.sh
    └── Memory structure validation

Backup & Recovery
├── snapshot.sh (daily 02:30 UTC) → GitHub backup
├── validate_backup.sh (daily 05:00 UTC)
├── trigger_backup_snapshot.sh (emergency)
└── restore.sh (manual recovery only)

Manual Diagnostics
├── backup_log_summary.sh (quick health check)
├── check_validation_status.sh
├── backup_monitor.sh
├── validate_blog_job.sh (blog cron monitoring)
└── rotate_backup_log.sh (manual log rotation)
```

---

## 🚨 Critical Rules for Scripts

1. **Always take a snapshot BEFORE changing config:**
   ```bash
   bash snapshot.sh "Clear description of change"
   ```

2. **Never run `openclaw` directly on host** — use `docker exec`

3. **Executable permissions:** All `.sh` files must have `+x` permission

4. **Logging:** Scripts should log actions/errors to `memory/` for audit trail

5. **Exit codes:** Scripts should return meaningful exit codes (0=success, non-zero=failure)

---

## 📅 Last Updated
2026-10-10 — Added `memory-hygiene.sh` (archives stale `.bak`/test leftovers from `memory/` to `memory/archive/`, dry-run default, never deletes) and wired it report-only into `weekly-safety-audit.sh` step 4b; first run archived 15 files aged 6+ months. Prior: 2026-10-08 — `log-self-improvement.sh` now auto-syncs AGENTS.md's "Recent Improvements" list after each write (closing the loop where logging an improvement re-staled the just-synced list and made the drift guard fire every morning); drift report now distinguishes count drift from date/order drift. Prior: 2026-10-07 — Added `sync-agents-improvements.sh` to keep AGENTS.md's "Recent Improvements" list from drifting behind the self-improvement log (section-scoped, idempotent), wired into the daily brief. Prior: 2026-10-05 documented the 20 scripts added since May (self-healing health checks, blocker/outbox/nudge tooling, Telegram & WooCommerce checks, snapshot stopgap, commit-workspace, self-improvement context) and added `check-scripts-doc.sh` to catch future doc drift.
2026-05-04 — Added `daily-status-summary.sh` and `health-quick-check.sh` for improved heartbeat monitoring and daily memory logging; resumes structured daily logging practice
