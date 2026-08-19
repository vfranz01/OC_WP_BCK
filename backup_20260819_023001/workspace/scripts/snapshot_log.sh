#!/bin/bash
# Logs successful snapshot creation time

TIMESTAMP=$(date '+%Y-%m-%d %H:%M UTC')
echo "Snapshot completed on: $TIMESTAMP" > /home/node/.openclaw/workspace/memory/last_snapshot.txt
