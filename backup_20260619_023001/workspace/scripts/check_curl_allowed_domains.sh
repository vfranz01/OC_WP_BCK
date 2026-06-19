#!/bin/bash
# Check if curl allowedDomains is set after OpenClaw updates
if python3 -c "import json; data = json.load(open('/opt/openclaw/data/openclaw.json')); print('allowedDomains' in str(data.get('safeBinProfiles', {})))" 2>/dev/null | grep -q "True"; then
  echo "OK: curl allowedDomains is set correctly."
  exit 0
else
  echo "WARNING: curl allowedDomains is missing. Please check /opt/openclaw-snapshots/v2026.3.28/NOTES.md for the fix."
  exit 1
fi
