#!/bin/bash
# Check if curl allowedDomains is set after OpenClaw updates
if cat /opt/openclaw/data/openclaw.json | python3 -m json.tool | grep -q -A10 "safeBinProfiles" | grep -q "allowedDomains"; then
  echo "curl allowedDomains is set correctly."
else
  echo "WARNING: curl allowedDomains is missing. Please check /opt/openclaw-snapshots/v2026.3.28/NOTES.md for the fix."
fi
