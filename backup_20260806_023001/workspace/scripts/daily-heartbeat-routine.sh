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

# 3. If health check failed, check logs
if [ $health_check_status -ne 0 ]; then
    echo "Health check failed. Checking backup incidents log:"
    tail -20 /home/node/.openclaw/workspace/memory/backup_incidents.log
fi

# Exit with status reflecting success/failure of sub-operations
exit $(($health_check_status + $status_summary_status))
