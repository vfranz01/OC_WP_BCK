#!/bin/bash
# check_woocommerce_key_age.sh
# Verifies that WooCommerce API keys have been rotated recently.
# Returns 0 = fresh, 1 = overdue/missing/invalid tracker, 2 = invalid threshold.
#
# Wire into health-quick-check.sh (heartbeat) to catch stale credentials proactively.
#
# Usage:
#   bash scripts/check_woocommerce_key_age.sh && echo "Keys fresh" || echo "Rotation overdue"

set -euo pipefail

WORKSPACE_DIR="/home/node/.openclaw/workspace"
TRACKER="$WORKSPACE_DIR/memory/security/woocommerce-key-rotation.md"
MAX_AGE_DAYS="${WOOKEY_MAX_AGE_DAYS:-90}"
# Bound input before Bash arithmetic: no expressions, octal, or overflow.
if [[ ! "$MAX_AGE_DAYS" =~ ^[0-9]{1,6}$ ]]; then
  echo "⚠️  WOOKEY_MAX_AGE_DAYS must be an integer from 0 to 999999"
  exit 2
fi
MAX_AGE_DAYS=$((10#$MAX_AGE_DAYS))

if [ ! -f "$TRACKER" ]; then
  echo "⚠️  WooCommerce key rotation never tracked — run rotate_woocommerce_keys.sh and confirm integrations"
  exit 1
fi

# Only the explicit completion field is authoritative, never frontmatter or
# audit-history dates. Require exactly one field; ambiguity fails closed.
if ! LAST=$(awk '
  /^[[:space:]]*-[[:space:]]+\*\*Last rotated:\*\*/ {
    count++
    value=$0
    sub(/^[[:space:]]*-[[:space:]]+\*\*Last rotated:\*\*[[:space:]]*/, "", value)
    sub(/[[:space:]]+$/, "", value)
  }
  END {if (count == 1) print value; else exit 1}
' "$TRACKER" 2>/dev/null); then
  echo "⚠️  WooCommerce tracker must contain exactly one '- **Last rotated:** YYYY-MM-DD' field"
  exit 1
fi
if [[ ! "$LAST" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ||
   ! LAST_EPOCH=$(date -u -d "$LAST" +%s 2>/dev/null); then
  echo "⚠️  WooCommerce tracker 'Last rotated' must be a valid YYYY-MM-DD completion date"
  exit 1
fi

# UTC midnights keep calendar-day ages stable across local DST transitions.
NOW_EPOCH=$(date -u -d "$(date -u +%Y-%m-%d)" +%s)
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