#!/bin/bash
# Check if curl allowedDomains is configured in OpenClaw config
# Supports both host VPS path (/opt/openclaw/data/openclaw.json) and container path (~/.openclaw/openclaw.json)

OPENCLAW_CONFIG=""
for candidate in "/opt/openclaw/data/openclaw.json" "$HOME/.openclaw/openclaw.json" "/home/node/.openclaw/openclaw.json"; do
    if [ -f "$candidate" ]; then
        OPENCLAW_CONFIG="$candidate"
        break
    fi
done

if [ -z "$OPENCLAW_CONFIG" ]; then
    echo "WARNING: openclaw.json not found in standard paths."
    exit 1
fi

# Check safeBinProfiles: if present, ensure allowedDomains is populated.
# If safeBinProfiles is not present in config, unrestricted execution applies.
check_res=$(python3 -c "
import json
try:
    with open('$OPENCLAW_CONFIG') as f:
        data = json.load(f)
    if 'safeBinProfiles' in data:
        profiles = data.get('safeBinProfiles', {})
        if profiles and 'allowedDomains' in str(profiles):
            print('OK')
        else:
            print('MISSING_IN_PROFILE')
    else:
        print('OK_NOT_CONFIGURED')
except Exception as e:
    print('ERROR:', e)
")

if [ "$check_res" = "OK" ] || [ "$check_res" = "OK_NOT_CONFIGURED" ]; then
    echo "OK: curl configuration is valid in $OPENCLAW_CONFIG."
    exit 0
else
    echo "WARNING: curl allowedDomains is missing in safeBinProfiles ($OPENCLAW_CONFIG)."
    echo "Please check TOOLS.md / snapshot notes for safeBinProfiles fix."
    exit 1
fi
