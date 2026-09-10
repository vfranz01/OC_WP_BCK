#!/bin/bash
# check_woocommerce_key_age.sh
# Verifies that WooCommerce API keys have been rotated recently.
# Returns 0 = OK (rotated within 90 days), non-zero = rotation overdue/missing.
#
# Wire into health-quick-check.sh (heartbeat) to catch stale credentials proactively.
#
# Usage:
#   bash scripts/check_woocommerce_key_age.sh && echo "Keys fresh" || echo "Rotation overdue"

set -euo pipefail

WORKSPACE_DIR="/home/node/.openclaw/workspace"
TRACKER="$WORKSPACE_DIR/memory/security/woocommerce-key-rotation.md"
MAX_AGE_DAYS="${WOOKEY_MAX_AGE_DAYS:-90}"

if [ ! -f "$TRACKER" ]; then
  echo "⚠️  WooCommerce key rotation never tracked — run rotate_woocommerce_keys.sh and confirm integrations"
  exit 1
fi

# Extract the ISO date from the tracker file
LAST=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$TRACKER" | head -1)
if [ -z "$LAST" ]; then
  echo "⚠️  WooCommerce rotation tracker has no valid date — please update it"
  exit 1
fi

LAST_EPOCH=$(date -d "$LAST" +%s)
NOW_EPOCH=$(date -d "$(date -u +%Y-%m-%d)" +%s)
DAYS_AGO=$(( (NOW_EPOCH - LAST_EPOCH) / 86400 ))

if [ "$DAYS_AGO" -lt 0 ]; then
  echo "⚠️  WooCommerce rotation date is in the future ($LAST) — check tracker"
  exit 1
fi

if [ "$DAYS_AGO" -le "$MAX_AGE_DAYS" ]; then
  echo "✅ WooCommerce keys rotated $DAYS_AGO day(s) ago (threshold ${MAX_AGE_DAYS}d)"
  exit 0
else
  echo "⚠️  WooCommerce keys last rotated $DAYS_AGO day(s) ago ($LAST) — rotation overdue (>${MAX_AGE_DAYS}d)"
  exit 1
fi