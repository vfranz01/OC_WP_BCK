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

**Typical use:**
```bash
bash snapshot.sh "Fixed blog post timezone issue"
bash snapshot.sh "Updated n8n webhook configuration"
```

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
4. ✅ Memory file structure integrity

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
**Purpose:** Create and publish a new blog post on T-ShirtBull Shopify store via API.

**Usage:**
```bash
bash create_tshirtbull_blog_post.sh "Post Title" "Post Content HTML"
```

**Parameters:**
- `$1`: Blog post title
- `$2`: Blog post content (HTML)

**Integration:**
- Called by blog automation workflows (Mondays/Wednesdays/Fridays at 9:00 AEST)
- Uses Shopify REST API credentials
- Creates and publishes post in one step

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

**Checks:**
- ✅ Backup system operational
- ✅ All critical files present
- ✅ Scripts are executable
- ✅ Recent memory logs exist

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
- 🔍 Extracts date from filename (YYYY-MM-DD format)
- 📝 Generates title from filename or content
- 🏷️ Auto-detects tags based on content keywords (heartbeat, blog, tshirtbull, etc.)
- 📄 Pulls first substantive line as summary (max 80 chars)
- 💾 Creates backups of original files in `memory/.backups/`
- 🛡️ Safe: no destructive actions without backup

**Parameters:**
- None — automatically processes all files needing frontmatter

**Integration:**
- One-time maintenance tool (already applied 2026-05-12)
- Can be re-run safely to update inconsistent files
- Creates backups for recovery if needed

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
2026-05-04 — Added `daily-status-summary.sh` and `health-quick-check.sh` for improved heartbeat monitoring and daily memory logging; resumes structured daily logging practice
