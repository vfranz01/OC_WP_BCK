#!/bin/bash
# Daily heartbeat routine to check system health and update memory logs.
# This script consolidates the commands previously listed directly in AGENTS.md.

# Ensure the memory directory exists
mkdir -p /home/node/.openclaw/workspace/memory

# 1. Run quick health check
/home/node/.openclaw/workspace/scripts/health-quick-check.sh
health_check_status=$?

# 2. Update daily memory log
/home/node/.openclaw/workspace/scripts/daily-status-summary.sh
status_summary_status=$?

# 2b. Refresh the auto-generated memory index (keeps the daily-log navigation current)
/home/node/.openclaw/workspace/scripts/update-memory-index.py

# 2c. Compact raw auto-promotion blocks out of MEMORY.md (keeps it under 5000 chars)
/home/node/.openclaw/workspace/scripts/compact-memory-promotions.sh

# 2d. Safety check: curl allowedDomains must be set after OpenClaw updates.
# TOOLS.md flags this as a critical post-update check. Warning-only (non-fatal)
# so a stale OpenClaw build never silently breaks the heartbeat.
if /home/node/.openclaw/workspace/scripts/check_curl_allowed_domains.sh >/dev/null 2>&1; then
    : # check passed
else
    echo "WARNING: curl allowedDomains may be missing after an OpenClaw update."
    echo "         Fix notes: /opt/openclaw-snapshots/v2026.3.28/NOTES.md"
    echo "         ($(date -u +%Y-%m-%dT%H:%M:%SZ)) failed" >> /home/node/.openclaw/workspace/memory/alloweddomains_check.log
fi

# 3. If health check failed, check logs
if [ $health_check_status -ne 0 ]; then
    echo "Health check failed. Checking backup incidents log:"
    tail -20 /home/node/.openclaw/workspace/memory/backup_incidents.log
fi

# Exit with status reflecting success/failure of sub-operations
exit $(($health_check_status + $status_summary_status))
