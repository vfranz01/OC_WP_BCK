#!/bin/bash

LOG_DIR="/home/node/.openclaw/workspace/logs"
mkdir -p "$LOG_DIR"

HEALTH_CHECK_SCRIPT="/home/node/.openclaw/workspace/scripts/health-quick-check.sh"
DAILY_STATUS_SCRIPT="/home/node/.openclaw/workspace/scripts/daily-status-summary.sh"
INCIDENTS_LOG="/home/node/.openclaw/workspace/memory/backup_incidents.log"

echo "--- Starting Daily Heartbeat Flow ---" | tee -a "$LOG_DIR/daily_heartbeat.log"
echo "Timestamp: $(date)" | tee -a "$LOG_DIR/daily_heartbeat.log"
echo "" | tee -a "$LOG_DIR/daily_heartbeat.log"

# Step 1: Run Health Check
echo "Running Health Check..." | tee -a "$LOG_DIR/daily_heartbeat.log"
if "$HEALTH_CHECK_SCRIPT" >> "$LOG_DIR/daily_heartbeat.log" 2>&1; then
    echo "Health Check: SUCCESS" | tee -a "$LOG_DIR/daily_heartbeat.log"
else
    HEALTH_CHECK_STATUS=$?
    echo "Health Check: FAILED with status $HEALTH_CHECK_STATUS" | tee -a "$LOG_DIR/daily_heartbeat.log"
    # Check for incidents log if health check fails
    if [ -s "$INCIDENTS_LOG" ]; then
        echo "" | tee -a "$LOG_DIR/daily_heartbeat.log"
        echo "--- Incidents Log ---" | tee -a "$LOG_DIR/daily_heartbeat.log"
        cat "$INCIDENTS_LOG" | tee -a "$LOG_DIR/daily_heartbeat.log"
        echo "---------------------" | tee -a "$LOG_DIR/daily_heartbeat.log"
    fi
fi
echo "" | tee -a "$LOG_DIR/daily_heartbeat.log"

# Step 2: Run Daily Status Summary
echo "Running Daily Status Summary..." | tee -a "$LOG_DIR/daily_heartbeat.log"
if "$DAILY_STATUS_SCRIPT" >> "$LOG_DIR/daily_heartbeat.log" 2>&1; then
    echo "Daily Status Summary: SUCCESS" | tee -a "$LOG_DIR/daily_heartbeat.log"
else
    DAILY_STATUS_STATUS=$?
    echo "Daily Status Summary: FAILED with status $DAILY_STATUS_STATUS" | tee -a "$LOG_DIR/daily_heartbeat.log"
fi
echo "" | tee -a "$LOG_DIR/daily_heartbeat.log"

echo "--- Daily Heartbeat Flow Completed ---" | tee -a "$LOG_DIR/daily_heartbeat.log"

exit 0
