# Scripts Documentation

This directory contains automation scripts for workspace management, backup, validation, and deployment tasks. All scripts are executable.

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

## 📊 Script Dependency Map

```
Heartbeat Checks (runs multiple times daily)
├── validate_backup.sh ──→ (fails) → trigger_backup_snapshot.sh
├── check_curl_allowed_domains.sh
├── check_tshirtbull_blogpost.sh (Mon/Wed/Fri only)
└── Memory maintenance (manual review)

Scheduled Cron Jobs
├── snapshot.sh (daily 02:30 UTC) → GitHub backup
└── Blog publishing (Mon/Wed/Fri 09:00 AEST)

Manual/Diagnostic
├── restore.sh (emergency restore only)
├── check_validation_status.sh
├── validate_critical_rules.sh
└── backup_monitor.sh
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
2026-05-02 — Fixed missing execute permissions on 4 scripts, created comprehensive documentation
