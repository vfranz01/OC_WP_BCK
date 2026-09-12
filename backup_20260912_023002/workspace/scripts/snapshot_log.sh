#!/bin/bash
# Logs successful snapshot creation time
# Usage: snapshot_log.sh [label]  (label passed through by snapshot.sh)

LABEL="${1:-manual}"
TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M UTC')
echo "Snapshot completed on: $TIMESTAMP (label: $LABEL)" > /home/node/.openclaw/workspace/memory/last_snapshot.txt
