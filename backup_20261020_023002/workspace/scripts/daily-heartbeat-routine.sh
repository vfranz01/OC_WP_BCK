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
memory_index_status=$?

# 2c. Compact raw auto-promotion blocks out of MEMORY.md (keeps it under 5000 chars)
/home/node/.openclaw/workspace/scripts/compact-memory-promotions.sh
compact_status=$?

# 2e. Stamp the heartbeat check tracker (memory/heartbeat-state.json).
# AGENTS.md documents this file as the routine tracker but nothing updated it.
/home/node/.openclaw/workspace/scripts/update-heartbeat-state.sh >/dev/null 2>&1
heartbeat_state_status=$?

# 2d. Safety check: curl allowedDomains must be set after OpenClaw updates.
# TOOLS.md warns this is a critical post-update check. Warning-only (non-fatal)
# so a stale OpenClaw build never silently breaks the heartbeat.
alloweddomains_status=0
if /home/node/.openclaw/workspace/scripts/check_curl_allowed_domains.sh >/dev/null 2>&1; then
    : # check passed
else
    alloweddomains_status=1
    echo "WARNING: curl allowedDomains missing after an OpenClaw update."
    echo "        Fix notes: /opt/openclaw-snapshots/v2026.3.28/NOTES.md"
    echo "        ($(date -u +%Y-%m-%dT%H:%M:%SZ)) failed" >> /home/node/.openclaw/workspace/memory/alloweddomains_check.log
fi

# 3. If health check failed, check logs
if [ "$health_check_status" -ne 0 ]; then
    echo "Health check failed. Checking backup incidents log:"
    tail -20 /home/node/.openclaw/workspace/memory/backup_incidents.log
fi

# Exit non-zero if ANY sub-step failed. Aggregate with logical OR instead of
# summing exit codes (sums can wrap past 255 and conflate one failure with
# another; a single non-zero flag is sufficient for cron alerting).
if [ "$health_check_status" -ne 0 ] || [ "$status_summary_status" -ne 0 ] \
   || [ "$memory_index_status" -ne 0 ] || [ "$compact_status" -ne 0 ] \
   || [ "$heartbeat_state_status" -ne 0 ] || [ "$alloweddomains_status" -ne 0 ]; then
    echo "daily-heartbeat-routine: one or more steps failed"
    exit 1
fi
exit 0
