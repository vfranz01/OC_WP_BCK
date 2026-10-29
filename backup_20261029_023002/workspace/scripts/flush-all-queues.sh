#!/bin/bash
# flush-all-queues.sh — ONE-COMMAND recovery for the Telegram outage backlog.
#
# Problem this fixes (2026-10-21): while the bot token is revoked (outage since
# 2026-09-23) every alert is persisted, not lost — but into TWO independent
# queues with two different flush commands:
#   • memory/undelivered-nudges.md          → send-blocker-nudges.sh --flush
#   • memory/undelivered-notifications.md   → telegram-send.sh --flush
# Recovery instructions were scattered across briefs and health output, so a
# partially-executed recovery was the likely outcome: flush one queue, forget
# the other, and nothing ever says "5 items are still stuck". This script makes
# recovery a single, verifiable action and refuses to waste a run on a token
# that is still dead.
#
# Order matters: blocker nudges go first (they carry the actual "do this next"
# asks), then generic notifications (backup/blog/health alerts) — so if Volker
# only reads the top of the burst, he reads the actionable part.
#
# Usage:
#   bash scripts/flush-all-queues.sh            # preflight + deliver both backlogs
#   bash scripts/flush-all-queues.sh --dry-run  # show sizes/preview, send nothing
#   bash scripts/flush-all-queues.sh --status   # queue sizes only, no network
#   bash scripts/flush-all-queues.sh --force    # skip the token preflight
#
# Exit codes: 0 = everything delivered / nothing queued,
#             1 = at least one item still undeliverable (kept in its queue),
#             2 = preflight says the channel is still dead (nothing attempted).
#
# Used by: daily-improvement routine, check_telegram_token.sh recovery hint.

set -uo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NUDGES="$WORKSPACE_DIR/scripts/send-blocker-nudges.sh"
SENDER="$WORKSPACE_DIR/scripts/telegram-send.sh"
QUEUE_TOOL="$WORKSPACE_DIR/scripts/notify-queue.py"
TOKEN_CHECK="$WORKSPACE_DIR/scripts/check_telegram_token.sh"

MODE="flush"
for arg in "$@"; do
  case "$arg" in
    --dry-run) MODE="dry" ;;
    --status)  MODE="status" ;;
    --force)   MODE="force_flush" ;;
    -h|--help) sed -n '2,33p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "flush-all-queues: unknown option: $arg" >&2; exit 2 ;;
  esac
done

for f in "$NUDGES" "$SENDER" "$QUEUE_TOOL"; do
  [ -f "$f" ] || { echo "flush-all-queues: missing $f" >&2; exit 2; }
done

NUDGE_N=$( [ -f "$WORKSPACE_DIR/memory/undelivered-nudges.md" ] \
  && grep -c '^## ' "$WORKSPACE_DIR/memory/undelivered-nudges.md" 2>/dev/null || echo 0 )
NOTIFY_N=$(python3 "$QUEUE_TOOL" list 2>/dev/null \
  | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)

show_status() {
  echo "📥 Delivery backlog: ${NUDGE_N} blocker nudge(s) + ${NOTIFY_N} notification(s)"
  if [ "$NUDGE_N" -gt 0 ]; then
    bash "$NUDGES" --status 2>/dev/null | sed -n '1,12p'
  fi
  if [ "$NOTIFY_N" -gt 0 ]; then
    python3 "$QUEUE_TOOL" status 2>/dev/null | sed -n '1,12p'
  fi
}

if [ "$MODE" = "status" ]; then
  show_status
  exit 0
fi

if [ "$NUDGE_N" -eq 0 ] && [ "$NOTIFY_N" -eq 0 ]; then
  echo "✅ No delivery backlog — both queues empty."
  exit 0
fi

if [ "$MODE" = "dry" ]; then
  show_status
  echo
  echo "→ Dry run: nothing sent. Real recovery: bash scripts/flush-all-queues.sh"
  exit 0
fi

# --- Preflight: don't burn a run (and 401 log noise) on a dead token --------
# check_telegram_token.sh is a free getMe probe. Skipped with --force for the
# case where the token is valid but the probe itself is broken.
if [ "$MODE" != "force_flush" ] && [ -f "$TOKEN_CHECK" ]; then
  if ! bash "$TOKEN_CHECK" >/tmp/flush_all_preflight.log 2>&1; then
    echo "🚫 Preflight: Telegram token still rejected — nothing attempted, backlog kept."
    grep -E '⚠️|🚨' /tmp/flush_all_preflight.log | head -4 | sed 's/^/   /'
    echo "   Backlog: ${NUDGE_N} nudge(s) + ${NOTIFY_N} notification(s) safely queued."
    echo "   Once the token works: bash scripts/flush-all-queues.sh"
    exit 2
  fi
fi

RC=0
echo "📤 Recovering both backlogs — nudges first, then notifications."
echo "── 1/2 blocker nudges ($NUDGE_N) ──"
if [ "$NUDGE_N" -gt 0 ]; then
  # --dedupe runs inside --flush too; kept explicit so the count above is real.
  bash "$NUDGES" --flush || RC=1
else
  echo "   (empty)"
fi

# Re-read: the notification count may have changed if a nudge call queued
# something new (it passes --no-queue, so this is belt-and-braces).
NOTIFY_N=$(python3 "$QUEUE_TOOL" list 2>/dev/null \
  | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)
echo "── 2/2 notifications ($NOTIFY_N) ──"
if [ "$NOTIFY_N" -gt 0 ]; then
  bash "$SENDER" --flush || RC=1
else
  echo "   (empty)"
fi

echo
if [ "$RC" -eq 0 ]; then
  echo "✅ Backlog recovery complete — Volker has everything from the outage."
else
  echo "⚠️  Partial recovery — see lines above; the rest stays queued (no duplicates on retry)."
fi
exit "$RC"
